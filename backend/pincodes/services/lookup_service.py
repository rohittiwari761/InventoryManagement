import logging
from typing import Dict, Optional
from django.core.cache import cache
from django.conf import settings
from pincodes.models import PinCode
from .external_api import (
    ExternalPincodeAPI,
    PincodeAPIError,
    PincodeNotFoundError,
    PincodeAPIRateLimitError
)

logger = logging.getLogger(__name__)


class PincodeLookupService:
    """
    Unified pincode lookup service with 3-tier architecture:
    1. Redis Cache (fastest, ~1ms)
    2. External API (medium, ~200ms)
    3. Database Fallback (fast, ~10ms)

    This ensures high availability and performance while keeping data fresh.
    """

    def __init__(self):
        self.external_api = ExternalPincodeAPI()
        self.cache_ttl = getattr(settings, 'PINCODE_CACHE_TTL', 86400)  # 24 hours
        self.fallback_to_db = getattr(settings, 'PINCODE_FALLBACK_TO_DB', True)

    def lookup(self, pincode: str) -> Dict:
        """
        Look up pincode using 3-tier architecture

        Args:
            pincode (str): 6-digit pincode to look up

        Returns:
            Dict: Pincode data with source indicator

        Raises:
            ValueError: If pincode format is invalid
            PincodeNotFoundError: If pincode is not found in any source
        """
        # Validate pincode format
        if not pincode or not pincode.isdigit() or len(pincode) != 6:
            raise ValueError(f"Invalid pincode format: {pincode}. Must be 6 digits.")

        # Tier 1: Try cache first
        cached_data = self._get_from_cache(pincode)
        if cached_data:
            logger.debug(f"Pincode {pincode} found in cache")
            cached_data['source'] = 'cache'
            return cached_data

        # Tier 2: Try external API
        try:
            api_data = self._get_from_api(pincode)
            # Cache the result for future requests
            self._save_to_cache(pincode, api_data)
            logger.info(f"Pincode {pincode} fetched from external API")
            api_data['source'] = 'api'
            return api_data
        except PincodeAPIRateLimitError as e:
            # Rate limit exceeded - immediately fallback to database
            logger.warning(f"API rate limit exceeded, falling back to database for {pincode}")
            if self.fallback_to_db:
                return self._get_from_database(pincode, source='database_rate_limit')
            raise
        except PincodeNotFoundError:
            # Not found in API - try database
            logger.info(f"Pincode {pincode} not found in API, trying database")
            if self.fallback_to_db:
                try:
                    return self._get_from_database(pincode, source='database')
                except PincodeNotFoundError:
                    # Not in database either
                    raise PincodeNotFoundError(f"Pincode {pincode} not found")
            raise
        except PincodeAPIError as e:
            # API error (timeout, connection, server error) - fallback to database
            logger.error(f"API error for {pincode}: {e}")
            if self.fallback_to_db:
                try:
                    db_data = self._get_from_database(pincode, source='database_api_error')
                    logger.info(f"Pincode {pincode} served from database (API error fallback)")
                    return db_data
                except PincodeNotFoundError:
                    # Not in database either - re-raise original API error
                    raise e
            raise

    def _get_from_cache(self, pincode: str) -> Optional[Dict]:
        """Get pincode data from Redis cache"""
        try:
            cache_key = f'pincode:{pincode}'
            data = cache.get(cache_key)
            return data if data else None
        except Exception as e:
            logger.warning(f"Cache error for {pincode}: {e}")
            return None

    def _save_to_cache(self, pincode: str, data: Dict) -> None:
        """Save pincode data to Redis cache"""
        try:
            cache_key = f'pincode:{pincode}'
            # Remove 'source' field before caching
            cache_data = {k: v for k, v in data.items() if k != 'source'}
            cache.set(cache_key, cache_data, self.cache_ttl)
            logger.debug(f"Cached pincode {pincode} for {self.cache_ttl} seconds")
        except Exception as e:
            logger.warning(f"Failed to cache pincode {pincode}: {e}")

    def _get_from_api(self, pincode: str) -> Dict:
        """
        Get pincode data from external API

        Raises:
            PincodeNotFoundError: If not found
            PincodeAPIRateLimitError: If rate limit exceeded
            PincodeAPIError: For other API errors
        """
        return self.external_api.lookup_pincode(pincode)

    def _get_from_database(self, pincode: str, source: str = 'database') -> Dict:
        """
        Get pincode data from local database

        Args:
            pincode (str): 6-digit pincode
            source (str): Source indicator for logging

        Returns:
            Dict: Pincode data

        Raises:
            PincodeNotFoundError: If not found in database
        """
        try:
            pin_obj = PinCode.objects.get(pincode=pincode)
            data = {
                'pincode': pin_obj.pincode,
                'post_office': pin_obj.post_office,
                'city': pin_obj.city,
                'district': pin_obj.district,
                'state': pin_obj.state,
                'source': source,
            }
            # Cache database result too (so next lookup is from cache)
            self._save_to_cache(pincode, data)
            return data
        except PinCode.DoesNotExist:
            raise PincodeNotFoundError(f"Pincode {pincode} not found in database")
        except Exception as e:
            logger.error(f"Database error for {pincode}: {e}")
            raise PincodeAPIError(f"Database error: {e}") from e

    def clear_cache(self, pincode: Optional[str] = None) -> None:
        """
        Clear pincode cache

        Args:
            pincode (str, optional): Specific pincode to clear. If None, clears all pincode cache.
        """
        try:
            if pincode:
                cache_key = f'pincode:{pincode}'
                cache.delete(cache_key)
                logger.info(f"Cleared cache for pincode {pincode}")
            else:
                # Clear all pincode cache keys
                cache.delete_pattern('pincode:*')
                logger.info("Cleared all pincode cache")
        except Exception as e:
            logger.error(f"Error clearing cache: {e}")

    def get_stats(self) -> Dict:
        """
        Get lookup service statistics

        Returns:
            Dict: Statistics about cache, API, database usage
        """
        # This would require implementing counters/metrics
        # For now, return basic info
        return {
            'cache_ttl': self.cache_ttl,
            'fallback_enabled': self.fallback_to_db,
            'api_base_url': self.external_api.base_url,
        }
