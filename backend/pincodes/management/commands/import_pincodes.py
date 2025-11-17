import csv
import os
from django.core.management.base import BaseCommand
from django.db import transaction
from pincodes.models import PinCode


class Command(BaseCommand):
    help = 'Import PIN codes from CSV file'

    def add_arguments(self, parser):
        parser.add_argument(
            '--file',
            type=str,
            default='pincodes_data.csv',
            help='Path to the CSV file (default: pincodes_data.csv)'
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear existing PIN codes before importing'
        )

    def handle(self, *args, **options):
        csv_file = options['file']
        
        # Check if file exists
        if not os.path.exists(csv_file):
            self.stdout.write(
                self.style.ERROR(f'File {csv_file} not found')
            )
            return

        # Clear existing data if requested
        if options['clear']:
            self.stdout.write('Clearing existing PIN codes...')
            PinCode.objects.all().delete()
            self.stdout.write(
                self.style.SUCCESS('Cleared existing PIN codes')
            )

        # Import data
        self.stdout.write(f'Importing PIN codes from {csv_file}...')
        
        imported_count = 0
        error_count = 0
        
        try:
            with open(csv_file, 'r', encoding='utf-8') as file:
                # Use transaction for better performance
                with transaction.atomic():
                    reader = csv.DictReader(file)
                    
                    for row in reader:
                        try:
                            # Extract data from CSV
                            pincode = row['Pincode'].strip()
                            post_office = row['PostOfficeName'].strip()
                            city = row['City'].strip()
                            district = row['DistrictsName'].strip()
                            state = row['State'].strip()
                            
                            # Validate PIN code format
                            if not pincode.isdigit() or len(pincode) != 6:
                                error_count += 1
                                continue
                            
                            # Create or update PIN code entry
                            pin_obj, created = PinCode.objects.get_or_create(
                                pincode=pincode,
                                defaults={
                                    'post_office': post_office,
                                    'city': city,
                                    'district': district,
                                    'state': state,
                                }
                            )
                            
                            if created:
                                imported_count += 1
                            
                            # Progress indicator
                            if imported_count % 1000 == 0:
                                self.stdout.write(f'Imported {imported_count} PIN codes...')
                                
                        except Exception as e:
                            self.stdout.write(
                                self.style.WARNING(f'Error processing row: {e}')
                            )
                            error_count += 1
                            continue

        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error reading CSV file: {e}')
            )
            return

        # Summary
        self.stdout.write(
            self.style.SUCCESS(
                f'Import completed! Imported: {imported_count}, Errors: {error_count}'
            )
        )
        
        # Show some statistics
        total_pincodes = PinCode.objects.count()
        unique_states = PinCode.objects.values_list('state', flat=True).distinct().count()
        unique_cities = PinCode.objects.values_list('city', flat=True).distinct().count()
        
        self.stdout.write(f'Total PIN codes in database: {total_pincodes}')
        self.stdout.write(f'Unique states: {unique_states}')
        self.stdout.write(f'Unique cities: {unique_cities}')