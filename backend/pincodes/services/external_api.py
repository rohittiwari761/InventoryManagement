import httpx
import logging
from typing import Dict, Optional
from django.conf import settings

logger = logging.getLogger(__name__)


class PincodeAPIError(Exception):
    """Base exception for pincode API errors"""
    pass


class PincodeNotFoundError(PincodeAPIError):
    """Raised when pincode is not found"""
    pass


class PincodeAPIRateLimitError(PincodeAPIError):
    """Raised when API rate limit is exceeded"""
    pass


class ExternalPincodeAPI:
    """
    Service for fetching pincode data from api.postalpincode.in

    API Details:
    - Base URL: https://api.postalpincode.in
    - Endpoint: /pincode/{pincode}
    - Method: GET
    - Authentication: None
    - Rate Limit: 1000 requests/hour per IP
    """

    def __init__(self):
        self.base_url = getattr(settings, 'PINCODE_API_URL', 'https://api.postalpincode.in')
        self.timeout = getattr(settings, 'PINCODE_API_TIMEOUT', 5)
        self.max_retries = getattr(settings, 'PINCODE_API_MAX_RETRIES', 2)

    def lookup_pincode(self, pincode: str) -> Dict:
        """
        Look up pincode from external API

        Args:
            pincode (str): 6-digit pincode to look up

        Returns:
            Dict: Pincode data with keys: pincode, post_office, city, district, state

        Raises:
            PincodeNotFoundError: If pincode is not found
            PincodeAPIRateLimitError: If rate limit is exceeded
            PincodeAPIError: For other API errors
        """
        # Validate pincode format
        if not pincode or not pincode.isdigit() or len(pincode) != 6:
            raise ValueError(f"Invalid pincode format: {pincode}")

        url = f"{self.base_url}/pincode/{pincode}"

        # Try with retries
        last_exception = None
        for attempt in range(self.max_retries + 1):
            try:
                response = self._make_request(url)
                return self._parse_response(response, pincode)
            except (httpx.TimeoutException, httpx.ConnectError) as e:
                last_exception = e
                logger.warning(
                    f"API request failed (attempt {attempt + 1}/{self.max_retries + 1}): {e}"
                )
                if attempt < self.max_retries:
                    continue
                else:
                    raise PincodeAPIError(f"API request failed after {self.max_retries + 1} attempts") from e
            except PincodeAPIRateLimitError:
                # Don't retry rate limit errors
                raise
            except PincodeNotFoundError:
                # Don't retry not found errors
                raise

        # If we get here, all retries failed
        if last_exception:
            raise PincodeAPIError(f"API request failed: {last_exception}") from last_exception

    def _make_request(self, url: str) -> Dict:
        """Make HTTP request to external API"""
        try:
            with httpx.Client(timeout=self.timeout) as client:
                response = client.get(url)

                # Check for rate limiting
                if response.status_code == 429:
                    logger.error("API rate limit exceeded")
                    raise PincodeAPIRateLimitError("API rate limit exceeded (1000 requests/hour)")

                # Check for server errors
                if response.status_code >= 500:
                    logger.error(f"API server error: {response.status_code}")
                    raise PincodeAPIError(f"API server error: {response.status_code}")

                # Check for client errors
                if response.status_code >= 400:
                    logger.warning(f"API client error: {response.status_code}")
                    raise PincodeAPIError(f"API error: {response.status_code}")

                return response.json()

        except httpx.TimeoutException as e:
            logger.warning(f"API request timeout: {url}")
            raise
        except httpx.ConnectError as e:
            logger.warning(f"API connection error: {url}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error calling API: {e}")
            raise PincodeAPIError(f"Unexpected API error: {e}") from e

    def _parse_response(self, data: Dict, pincode: str) -> Dict:
        """
        Parse and transform API response to match our format

        API Response Format:
        [
          {
            "Message": "Number of pincode(s) found:1",
            "Status": "Success",
            "PostOffice": [
              {
                "Name": "Post Office Name",
                "Pincode": "110001",
                "District": "Central Delhi",
                "State": "Delhi",
                "Block": "New Delhi"
              }
            ]
          }
        ]

        Our Format:
        {
            "pincode": "110001",
            "post_office": "Post Office Name",
            "city": "New Delhi",
            "district": "Central Delhi",
            "state": "Delhi"
        }
        """
        try:
            # Response is an array with one element
            if not isinstance(data, list) or len(data) == 0:
                logger.error(f"Invalid API response format for pincode {pincode}")
                raise PincodeAPIError("Invalid API response format")

            result = data[0]
            status = result.get('Status', '')

            # Check if pincode was found
            if status.lower() != 'success':
                message = result.get('Message', '')
                logger.info(f"Pincode {pincode} not found: {message}")
                raise PincodeNotFoundError(f"Pincode {pincode} not found")

            # Get post office data
            post_offices = result.get('PostOffice', [])
            if not post_offices or len(post_offices) == 0:
                logger.info(f"No post office data for pincode {pincode}")
                raise PincodeNotFoundError(f"No data found for pincode {pincode}")

            # Use the first post office (usually the main one)
            post_office = post_offices[0]

            # Transform to our format
            return {
                'pincode': post_office.get('Pincode', pincode),
                'post_office': post_office.get('Name', ''),
                'city': post_office.get('Block', '') or post_office.get('District', ''),
                'district': post_office.get('District', ''),
                'state': post_office.get('State', ''),
            }

        except (PincodeNotFoundError, PincodeAPIError):
            raise
        except Exception as e:
            logger.error(f"Error parsing API response for pincode {pincode}: {e}")
            raise PincodeAPIError(f"Error parsing API response: {e}") from e
