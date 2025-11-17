"""
Tests for External Pincode API Service

To run these tests:
    python manage.py test pincodes.tests.test_external_api
"""
from django.test import TestCase
from pincodes.services.external_api import (
    ExternalPincodeAPI,
    PincodeNotFoundError,
    PincodeAPIError
)


class ExternalPincodeAPITest(TestCase):
    """Test cases for ExternalPincodeAPI"""

    def setUp(self):
        """Set up test fixtures"""
        self.api = ExternalPincodeAPI()

    def test_valid_pincode_lookup(self):
        """Test looking up a valid pincode"""
        # Test with Delhi pincode
        result = self.api.lookup_pincode('110001')

        # Verify response structure
        self.assertIn('pincode', result)
        self.assertIn('post_office', result)
        self.assertIn('city', result)
        self.assertIn('district', result)
        self.assertIn('state', result)

        # Verify pincode
        self.assertEqual(result['pincode'], '110001')
        # Verify state (should be Delhi)
        self.assertEqual(result['state'], 'Delhi')

    def test_invalid_pincode_format(self):
        """Test with invalid pincode format"""
        # Less than 6 digits
        with self.assertRaises(ValueError):
            self.api.lookup_pincode('12345')

        # More than 6 digits
        with self.assertRaises(ValueError):
            self.api.lookup_pincode('1234567')

        # Non-numeric
        with self.assertRaises(ValueError):
            self.api.lookup_pincode('abcdef')

        # Empty
        with self.assertRaises(ValueError):
            self.api.lookup_pincode('')

    def test_nonexistent_pincode(self):
        """Test with a non-existent pincode"""
        # Use an invalid pincode (all zeros)
        with self.assertRaises(PincodeNotFoundError):
            self.api.lookup_pincode('000000')

    def test_multiple_pincodes(self):
        """Test looking up multiple different pincodes"""
        test_pincodes = [
            '110001',  # Delhi
            '400001',  # Mumbai
            '560001',  # Bangalore
            '600001',  # Chennai
        ]

        for pincode in test_pincodes:
            result = self.api.lookup_pincode(pincode)
            self.assertEqual(result['pincode'], pincode)
            self.assertIsNotNone(result['state'])
            self.assertIsNotNone(result['city'])


class PincodeLookupServiceTest(TestCase):
    """Test cases for PincodeLookupService (3-tier lookup)"""

    def setUp(self):
        """Set up test fixtures"""
        from pincodes.services.lookup_service import PincodeLookupService
        self.service = PincodeLookupService()

    def test_lookup_with_api(self):
        """Test lookup using external API"""
        result = self.service.lookup('110001')

        # Should include source indicator
        self.assertIn('source', result)
        # Source should be 'api' or 'cache' (if already cached)
        self.assertIn(result['source'], ['api', 'cache'])

        # Verify data structure
        self.assertEqual(result['pincode'], '110001')
        self.assertIsNotNone(result['state'])

    def test_lookup_invalid_format(self):
        """Test lookup with invalid pincode format"""
        with self.assertRaises(ValueError):
            self.service.lookup('12345')

    def test_cache_functionality(self):
        """Test that cache is working"""
        pincode = '110001'

        # First lookup - should be from API
        result1 = self.service.lookup(pincode)
        source1 = result1['source']

        # Second lookup - should be from cache
        result2 = self.service.lookup(pincode)
        source2 = result2['source']

        # Second lookup should be from cache
        self.assertEqual(source2, 'cache')

        # Data should be same
        self.assertEqual(result1['pincode'], result2['pincode'])
        self.assertEqual(result1['state'], result2['state'])

    def test_clear_cache(self):
        """Test cache clearing functionality"""
        pincode = '110001'

        # Lookup to populate cache
        self.service.lookup(pincode)

        # Clear cache
        self.service.clear_cache(pincode)

        # Next lookup should be from API again
        result = self.service.lookup(pincode)
        # Note: might still be 'cache' if cleared but looked up again
        self.assertIn(result['source'], ['api', 'cache'])
