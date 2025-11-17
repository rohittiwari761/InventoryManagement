from django.core.management.base import BaseCommand
from django.db.models import Count
from apps.items.models import StoreInventory


class Command(BaseCommand):
    help = 'Remove duplicate StoreInventory records and keep the one with highest quantity'

    def handle(self, *args, **options):
        # Find duplicates by grouping on item, store, and company
        duplicates = (StoreInventory.objects
                     .values('item', 'store', 'company')
                     .annotate(count=Count('id'))
                     .filter(count__gt=1))

        total_removed = 0

        for dup in duplicates:
            # Get all records for this combination
            records = StoreInventory.objects.filter(
                item_id=dup['item'],
                store_id=dup['store'],
                company_id=dup['company']
            ).order_by('-quantity', '-id')  # Order by quantity desc, then ID desc

            # Keep the first one (highest quantity or most recent)
            keep_record = records.first()

            # Delete all others
            records_to_delete = records.exclude(id=keep_record.id)
            delete_count = records_to_delete.count()

            if delete_count > 0:
                self.stdout.write(
                    self.style.WARNING(
                        f'Found {delete_count} duplicate(s) for Item {dup["item"]}, '
                        f'Store {dup["store"]}, Company {dup["company"]} '
                        f'- Keeping ID {keep_record.id} with quantity {keep_record.quantity}'
                    )
                )
                records_to_delete.delete()
                total_removed += delete_count

        if total_removed > 0:
            self.stdout.write(
                self.style.SUCCESS(
                    f'Successfully removed {total_removed} duplicate inventory record(s)'
                )
            )
        else:
            self.stdout.write(
                self.style.SUCCESS('No duplicate inventory records found')
            )
