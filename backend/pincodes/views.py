from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from django.shortcuts import get_object_or_404
from .models import PinCode
from .serializers import PinCodeSerializer, PinCodeLookupSerializer
from .services import PincodeLookupService
from .services.external_api import PincodeNotFoundError, PincodeAPIError
import logging

logger = logging.getLogger(__name__)


class PinCodeListView(generics.ListAPIView):
    """List all PIN codes - for admin purposes"""
    queryset = PinCode.objects.all()
    serializer_class = PinCodeSerializer
    permission_classes = [AllowAny]  # You can restrict this later


@api_view(['GET'])
@permission_classes([AllowAny])
def lookup_pincode(request, pincode):
    """
    Lookup city and state by PIN code using 3-tier architecture:
    1. Redis Cache (fastest)
    2. External API (api.postalpincode.in)
    3. Local Database (fallback)

    GET /api/pincodes/lookup/110001/

    Response includes X-Data-Source header indicating data source:
    - cache: From Redis cache
    - api: From external API
    - database: From local database (fallback)
    """
    try:
        # Validate PIN code format
        if not pincode.isdigit() or len(pincode) != 6:
            return Response({
                'error': 'Invalid PIN code format. Must be 6 digits.'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Use the new lookup service
        lookup_service = PincodeLookupService()
        data = lookup_service.lookup(pincode)

        # Extract source for header
        source = data.pop('source', 'unknown')

        response = Response({
            'success': True,
            'data': data
        }, status=status.HTTP_200_OK)

        # Add header indicating data source
        response['X-Data-Source'] = source

        return response

    except ValueError as e:
        # Invalid format
        return Response({
            'success': False,
            'error': str(e),
            'pincode': pincode
        }, status=status.HTTP_400_BAD_REQUEST)

    except PincodeNotFoundError:
        return Response({
            'success': False,
            'error': 'PIN code not found',
            'pincode': pincode
        }, status=status.HTTP_404_NOT_FOUND)

    except PincodeAPIError as e:
        # API error and no database fallback
        logger.error(f"Pincode lookup failed for {pincode}: {e}")
        return Response({
            'success': False,
            'error': 'Unable to lookup PIN code. Please try again later.',
            'pincode': pincode
        }, status=status.HTTP_503_SERVICE_UNAVAILABLE)

    except Exception as e:
        # Unexpected error
        logger.error(f"Unexpected error looking up pincode {pincode}: {e}")
        return Response({
            'success': False,
            'error': 'An unexpected error occurred',
            'pincode': pincode
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def lookup_pincode_post(request):
    """
    Lookup city and state by PIN code via POST using 3-tier architecture

    POST /api/pincodes/lookup/
    Body: {"pincode": "110001"}

    Response includes X-Data-Source header indicating data source
    """
    serializer = PinCodeLookupSerializer(data=request.data)
    if serializer.is_valid():
        pincode = serializer.validated_data['pincode']

        try:
            # Use the new lookup service
            lookup_service = PincodeLookupService()
            data = lookup_service.lookup(pincode)

            # Extract source for header
            source = data.pop('source', 'unknown')

            response = Response({
                'success': True,
                'data': data
            }, status=status.HTTP_200_OK)

            # Add header indicating data source
            response['X-Data-Source'] = source

            return response

        except ValueError as e:
            return Response({
                'success': False,
                'error': str(e),
                'pincode': pincode
            }, status=status.HTTP_400_BAD_REQUEST)

        except PincodeNotFoundError:
            return Response({
                'success': False,
                'error': 'PIN code not found',
                'pincode': pincode
            }, status=status.HTTP_404_NOT_FOUND)

        except PincodeAPIError as e:
            logger.error(f"Pincode lookup failed for {pincode}: {e}")
            return Response({
                'success': False,
                'error': 'Unable to lookup PIN code. Please try again later.',
                'pincode': pincode
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        except Exception as e:
            logger.error(f"Unexpected error looking up pincode {pincode}: {e}")
            return Response({
                'success': False,
                'error': 'An unexpected error occurred',
                'pincode': pincode
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    return Response({
        'success': False,
        'error': 'Invalid request data',
        'errors': serializer.errors
    }, status=status.HTTP_400_BAD_REQUEST)
