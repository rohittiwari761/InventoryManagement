import io
import os
from datetime import datetime, date
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image, KeepTogether
from reportlab.lib.enums import TA_CENTER, TA_RIGHT, TA_LEFT
from django.conf import settings


def format_indian_currency(amount):
    """
    Format currency with Indian comma placement (lakh/crore system).

    Args:
        amount: Decimal or float value

    Returns:
        str: Formatted amount with commas (e.g., "1,23,456.78")

    Examples:
        123456.78 -> "1,23,456.78"
        1234567.89 -> "12,34,567.89"
        12345678.90 -> "1,23,45,678.90"
    """
    # Convert to float and format with 2 decimal places
    amount_float = float(amount)

    # Split into integer and decimal parts
    int_part = int(abs(amount_float))
    decimal_part = f"{abs(amount_float):.2f}".split('.')[1]

    # Convert integer part to string
    int_str = str(int_part)

    # Handle Indian comma placement
    if len(int_str) <= 3:
        formatted = int_str
    else:
        # Last 3 digits
        last_three = int_str[-3:]
        # Remaining digits
        remaining = int_str[:-3]

        # Add commas every 2 digits from right for remaining part
        formatted_remaining = ""
        while len(remaining) > 2:
            formatted_remaining = "," + remaining[-2:] + formatted_remaining
            remaining = remaining[:-2]

        if remaining:
            formatted_remaining = remaining + formatted_remaining

        formatted = formatted_remaining + "," + last_three

    # Add decimal part
    result = f"{formatted}.{decimal_part}"

    # Add negative sign if needed
    if amount_float < 0:
        result = "-" + result

    return result


def get_financial_year(input_date=None):
    """
    Calculate Indian financial year from a given date.
    Financial year runs from April 1 to March 31.

    Args:
        input_date: datetime.date, datetime.datetime, or None (uses current date)

    Returns:
        str: Financial year in format "YYYY-YY" (e.g., "2024-25")

    Examples:
        March 31, 2025 -> "2024-25"
        April 1, 2025 -> "2025-26"
        January 15, 2025 -> "2024-25"
        December 20, 2024 -> "2024-25"
    """
    if input_date is None:
        input_date = datetime.now().date()
    elif isinstance(input_date, datetime):
        input_date = input_date.date()

    # Financial year starts on April 1
    if input_date.month >= 4:  # April to December
        fy_start_year = input_date.year
        fy_end_year = input_date.year + 1
    else:  # January to March
        fy_start_year = input_date.year - 1
        fy_end_year = input_date.year

    # Format: "2024-25" (last 2 digits of end year)
    return f"{fy_start_year}-{str(fy_end_year)[-2:]}"


def get_fy_date_range(input_date=None):
    """
    Get the start and end dates of the financial year for a given date.

    Args:
        input_date: datetime.date, datetime.datetime, or None (uses current date)

    Returns:
        tuple: (fy_start_date, fy_end_date) as date objects

    Examples:
        March 31, 2025 -> (date(2024, 4, 1), date(2025, 3, 31))
        April 1, 2025 -> (date(2025, 4, 1), date(2026, 3, 31))
        January 15, 2025 -> (date(2024, 4, 1), date(2025, 3, 31))
    """
    if input_date is None:
        input_date = datetime.now().date()
    elif isinstance(input_date, datetime):
        input_date = input_date.date()

    # Determine FY start year
    if input_date.month >= 4:  # April to December
        fy_start_year = input_date.year
        fy_end_year = input_date.year + 1
    else:  # January to March
        fy_start_year = input_date.year - 1
        fy_end_year = input_date.year

    fy_start = date(fy_start_year, 4, 1)
    fy_end = date(fy_end_year, 3, 31)

    return fy_start, fy_end


def generate_invoice_pdf(invoice, layout='traditional'):
    """
    Generate invoice PDF with support for different layouts.

    Args:
        invoice: Invoice model instance
        layout: 'classic' or 'traditional' (default: 'traditional')
            - classic: Compact layout with simplified header and grey theme
            - traditional: Full GST-compliant layout with blue theme (default)
    """
    buffer = io.BytesIO()

    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        topMargin=15*mm,
        bottomMargin=15*mm,
        leftMargin=15*mm,
        rightMargin=15*mm
    )

    styles = getSampleStyleSheet()

    # Layout-specific color schemes
    if layout == 'classic':
        # Classic: Grey professional theme
        header_color = colors.HexColor('#4A4A4A')  # Dark grey
        accent_color = colors.HexColor('#757575')  # Medium grey
    else:
        # Traditional: Blue GST-compliant theme
        header_color = colors.HexColor('#2E86C1')  # Blue
        accent_color = colors.HexColor('#3498DB')  # Light blue

    # Custom styles to match GST invoice
    title_style = ParagraphStyle(
        'TitleStyle',
        parent=styles['Normal'],
        fontSize=16,
        fontName='Helvetica-Bold',
        alignment=TA_CENTER,
        textColor=colors.white,
        backColor=header_color,
        spaceAfter=3*mm,
        leftIndent=0,
        rightIndent=0,
        topPadding=6*mm,
        bottomPadding=6*mm,
    )
    
    subtitle_style = ParagraphStyle(
        'SubtitleStyle',
        parent=styles['Normal'],
        fontSize=8,
        fontName='Helvetica',
        alignment=TA_CENTER,
        spaceAfter=3*mm,
    )
    
    header_style = ParagraphStyle(
        'HeaderStyle',
        parent=styles['Normal'],
        fontSize=9,
        fontName='Helvetica-Bold',
        alignment=TA_LEFT,
    )
    
    normal_style = ParagraphStyle(
        'NormalStyle',
        parent=styles['Normal'],
        fontSize=8,
        fontName='Helvetica',
        alignment=TA_LEFT,
    )
    
    elements = []

    # Add company logo if available
    if invoice.company.logo:
        try:
            logo_path = os.path.join(settings.MEDIA_ROOT, str(invoice.company.logo))
            if os.path.exists(logo_path):
                logo = Image(logo_path, width=40*mm, height=15*mm, kind='proportional')
                logo.hAlign = 'CENTER'
                elements.append(logo)
                elements.append(Spacer(1, 3*mm))
        except Exception as e:
            # If logo fails to load, continue without it
            pass

    # Title Section - layout-specific
    title = Paragraph("TAX INVOICE", title_style)
    elements.append(title)

    # Only show subtitle in traditional layout
    if layout == 'traditional':
        subtitle = Paragraph("(Original for Recipient)<br/>As per GST Rules 2017", subtitle_style)
        elements.append(subtitle)
    else:
        # Classic layout: simpler subtitle
        subtitle = Paragraph("(Original for Recipient)", subtitle_style)
        elements.append(subtitle)
    
    # Top section with supplier details and invoice info
    supplier_details = f"""
    <b>Details of Supplier (Billed From):</b><br/>
    <b>{invoice.company.name}</b><br/>
    {invoice.company.address}<br/>
    {invoice.company.city}, {invoice.company.state} - {invoice.company.pincode}<br/>
    Email: {invoice.company.email}<br/>
    Phone: {invoice.company.phone}
    """
    
    # Invoice details table
    invoice_details_data = [
        ['Invoice No.:', invoice.invoice_number],
        ['Invoice Date:', invoice.invoice_date.strftime('%d/%m/%Y')],
        ['Due Date:', invoice.due_date.strftime('%d/%m/%Y') if invoice.due_date else 'N/A'],
        ['Place of Supply:', invoice.place_of_supply or invoice.company.state],
        ['Reverse Charge:', invoice.reverse_charge],
    ]
    
    invoice_details_table = Table(invoice_details_data, colWidths=[30*mm, 40*mm])
    invoice_details_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 1),
    ]))
    
    # GST details table
    gst_details_data = [
        ['GSTIN:', invoice.company.gstin],
        ['PAN:', invoice.company.pan],
        ['State:', invoice.company.state],
        ['State Code:', getattr(invoice.company, 'state_code', '10')],
    ]
    
    gst_details_table = Table(gst_details_data, colWidths=[20*mm, 40*mm])
    gst_details_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 1),
        ('TOPPADDING', (0, 0), (-1, -1), 1),
        ('LEFTPADDING', (0, 0), (-1, -1), 2),
        ('RIGHTPADDING', (0, 0), (-1, -1), 2),
    ]))
    
    # Top section table combining supplier and invoice details
    top_section_data = [
        [
            Paragraph(supplier_details, normal_style),
            invoice_details_table
        ],
        [
            gst_details_table,
            ''
        ]
    ]
    
    top_table = Table(top_section_data, colWidths=[100*mm, 80*mm])
    top_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('GRID', (0, 0), (-1, -1), 1, colors.black),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    
    elements.append(top_table)
    elements.append(Spacer(1, 2*mm))
    
    # Customer details section - use billing address if present, otherwise customer default
    # Use invoice-specific billing address if set, otherwise use customer's default address
    billing_addr = invoice.billing_address if invoice.billing_address and invoice.billing_address.strip() else invoice.customer.address
    billing_city = invoice.billing_city if invoice.billing_city and invoice.billing_city.strip() else invoice.customer.city
    billing_state = invoice.billing_state if invoice.billing_state and invoice.billing_state.strip() else invoice.customer.state
    billing_pincode = invoice.billing_pincode if invoice.billing_pincode and invoice.billing_pincode.strip() else invoice.customer.pincode

    customer_info = f"""
    <b>Details of Receiver (Billed To):</b><br/>
    <b>Name:</b> {invoice.customer.name}<br/>
    <b>Address:</b> {billing_addr}<br/>
    {billing_city}, {billing_state} - {billing_pincode}
    """

    # Customer contact and GST details
    customer_contact = f"<b>Phone:</b> {invoice.customer.phone}"
    if invoice.customer.email:
        customer_contact += f"<br/><b>Email:</b> {invoice.customer.email}"
    if invoice.customer.gstin:
        customer_contact += f"<br/><b>GSTIN:</b> {invoice.customer.gstin}"

    customer_data = [
        [
            Paragraph(customer_info, normal_style),
            Paragraph(customer_contact, normal_style)
        ]
    ]

    customer_table = Table(customer_data, colWidths=[130*mm, 50*mm])
    customer_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('GRID', (0, 0), (-1, -1), 1, colors.black),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    
    elements.append(customer_table)
    elements.append(Spacer(1, 3*mm))
    
    # Items table - exactly like GST invoice
    items_header = [
        'S.No',
        'Description of Goods/Services',
        'HSN/SAC',
        'Qty',
        'Unit',
        'Rate (₹)',
        'Taxable Value (₹)',
        'Tax Rate',
        'CGST (₹)',
        'SGST (₹)',
        'Total (₹)'
    ]
    
    items_data = [items_header]
    
    # Add invoice items
    for idx, item in enumerate(invoice.items.all(), 1):
        tax_rate_display = f"{item.tax_rate:.1f}%" if item.tax_rate > 0 else "0.00%"
        
        # Show CGST/SGST for intra-state, IGST for inter-state in CGST column
        cgst_display = f"{item.cgst_amount:.2f}" if item.cgst_amount > 0 else f"{item.igst_amount:.2f}"
        sgst_display = f"{item.sgst_amount:.2f}" if item.sgst_amount > 0 else "0.00"
        
        items_data.append([
            str(idx),
            item.item.name,
            item.item.hsn_code or '',
            f"{item.quantity:.0f}",
            item.item.unit.upper(),
            f"₹{format_indian_currency(item.unit_price)}",
            f"₹{format_indian_currency(item.subtotal)}",
            tax_rate_display,
            f"₹{format_indian_currency(float(cgst_display))}",
            f"₹{format_indian_currency(float(sgst_display))}",
            f"₹{format_indian_currency(item.total_amount)}",
        ])
    
    # Items table styling - with repeatRows for multi-page support
    items_table = Table(items_data, colWidths=[
        12*mm,  # S.No
        45*mm,  # Description
        18*mm,  # HSN/SAC
        12*mm,  # Qty
        12*mm,  # Unit
        18*mm,  # Rate
        22*mm,  # Taxable Value
        15*mm,  # Tax Rate
        18*mm,  # CGST
        18*mm,  # SGST
        20*mm,  # Total
    ], repeatRows=1, splitByRow=True)
    
    # Layout-specific table styling
    if layout == 'classic':
        # Classic: Simple grey header
        table_style = TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#E0E0E0')),  # Light grey
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 7),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 7),
            ('ALIGN', (0, 1), (0, -1), 'CENTER'),
            ('ALIGN', (1, 1), (1, -1), 'LEFT'),
            ('ALIGN', (2, 1), (-1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 2),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 2),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
        ])
    else:
        # Traditional: Original lightgrey header
        table_style = TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.lightgrey),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 7),
            ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 7),
            ('ALIGN', (0, 1), (0, -1), 'CENTER'),
            ('ALIGN', (1, 1), (1, -1), 'LEFT'),
            ('ALIGN', (2, 1), (-1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 2),
            ('RIGHTPADDING', (0, 0), (-1, -1), 2),
            ('TOPPADDING', (0, 0), (-1, -1), 2),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
        ])

    items_table.setStyle(table_style)
    
    elements.append(items_table)
    elements.append(Spacer(1, 3*mm))
    
    # Tax Summary and Amount Details - side by side like GST invoice
    # Left side - Tax Summary
    tax_summary_header = ['Tax Rate', 'Taxable Amount (₹)', 'CGST (₹)', 'SGST (₹)', 'Total Tax (₹)']
    tax_summary_data = [tax_summary_header]
    
    # Calculate totals for tax summary
    total_taxable = float(invoice.subtotal)
    total_cgst = float(invoice.cgst_amount)
    total_sgst = float(invoice.sgst_amount)
    total_igst = float(invoice.igst_amount)
    
    # Add tax summary row
    if total_cgst > 0 and total_sgst > 0:
        # Intra-state
        tax_summary_data.append([
            "GST",
            f"₹{format_indian_currency(total_taxable)}",
            f"₹{format_indian_currency(total_cgst)}",
            f"₹{format_indian_currency(total_sgst)}",
            f"₹{format_indian_currency(total_cgst + total_sgst)}"
        ])
    elif total_igst > 0:
        # Inter-state - show IGST in CGST column, 0 in SGST
        tax_summary_data.append([
            "GST",
            f"₹{format_indian_currency(total_taxable)}",
            f"₹{format_indian_currency(total_igst)}",
            "₹0.00",
            f"₹{format_indian_currency(total_igst)}"
        ])
    
    tax_summary_table = Table(tax_summary_data, colWidths=[20*mm, 25*mm, 20*mm, 20*mm, 25*mm])
    tax_summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 7),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 8),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.black),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ]))
    
    # Right side - Amount Details (conditional based on inter-state vs intra-state)
    amount_details_data = [['Sub Total:', f"₹{format_indian_currency(invoice.subtotal)}"]]

    # Add tax rows based on transaction type
    if total_igst > 0:
        # Inter-state: Show IGST
        amount_details_data.append(['Total IGST:', f"₹{format_indian_currency(invoice.igst_amount)}"])
    else:
        # Intra-state: Show CGST + SGST
        amount_details_data.append(['Total CGST:', f"₹{format_indian_currency(invoice.cgst_amount)}"])
        amount_details_data.append(['Total SGST:', f"₹{format_indian_currency(invoice.sgst_amount)}"])

    amount_details_data.extend([
        ['Total Tax Amount:', f"₹{format_indian_currency(invoice.total_tax)}"],
        ['Round Off:', f"₹{format_indian_currency(invoice.round_off)}"],
    ])
    
    amount_details_table = Table(amount_details_data, colWidths=[25*mm, 25*mm])
    amount_details_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('ALIGN', (0, 0), (0, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
    ]))
    
    # Combine tax summary and amount details
    bottom_section_data = [
        [
            Paragraph("<b>Tax Summary</b>", header_style),
            Paragraph("<b>Amount Details</b>", header_style)
        ],
        [
            tax_summary_table,
            amount_details_table
        ]
    ]
    
    bottom_table = Table(bottom_section_data, colWidths=[110*mm, 70*mm])
    bottom_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('GRID', (0, 0), (-1, -1), 1, colors.black),
    ]))
    
    elements.append(bottom_table)
    elements.append(Spacer(1, 3*mm))
    
    # Total Invoice Value - prominent box
    total_box_data = [
        [f"Total Invoice Value: ₹{format_indian_currency(invoice.total_amount)}"]
    ]
    total_box_table = Table(total_box_data, colWidths=[180*mm])
    total_box_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 12),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('GRID', (0, 0), (-1, -1), 2, colors.black),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
    ]))
    
    elements.append(total_box_table)
    elements.append(Spacer(1, 2*mm))
    
    # Amount in words
    amount_in_words = invoice.amount_in_words or invoice.number_to_words(int(invoice.total_amount))
    words_data = [
        [f"Amount in Words:\n{amount_in_words}"]
    ]
    words_table = Table(words_data, colWidths=[180*mm])
    words_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('GRID', (0, 0), (-1, -1), 1, colors.black),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
    ]))
    
    elements.append(words_table)
    elements.append(Spacer(1, 3*mm))

    # Invoice notes section (if notes exist)
    if invoice.notes and invoice.notes.strip():
        notes_data = [
            [Paragraph(f"<b>Notes:</b><br/>{invoice.notes}", normal_style)]
        ]
        notes_table = Table(notes_data, colWidths=[180*mm])
        notes_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 8),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ]))
        elements.append(notes_table)
        elements.append(Spacer(1, 3*mm))

    # Bank details section
    bank_details_text = "<b>Bank Account Details:</b><br/>"
    if invoice.company.bank_name:
        bank_details_text += f"Bank Name: {invoice.company.bank_name}<br/>"
    if invoice.company.bank_account_number:
        bank_details_text += f"Account Number: {invoice.company.bank_account_number}<br/>"
    if invoice.company.bank_ifsc:
        bank_details_text += f"IFSC Code: {invoice.company.bank_ifsc}<br/>"
    if invoice.company.bank_branch:
        bank_details_text += f"Branch: {invoice.company.bank_branch}"

    # Only show bank details section if at least one field is filled
    has_bank_details = any([
        invoice.company.bank_name,
        invoice.company.bank_account_number,
        invoice.company.bank_ifsc,
        invoice.company.bank_branch
    ])

    if has_bank_details:
        bank_data = [
            [Paragraph(bank_details_text, normal_style)]
        ]
        bank_table = Table(bank_data, colWidths=[180*mm])
        bank_table.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 8),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ('TOPPADDING', (0, 0), (-1, -1), 5),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ]))
        elements.append(bank_table)
        elements.append(Spacer(1, 3*mm))

    # Logistics/Driver Details section (if enabled)
    if invoice.include_logistics:
        logistics_details_text = "<b>Logistics Details:</b><br/>"
        has_logistics_data = False

        if invoice.driver_name:
            logistics_details_text += f"Driver Name: {invoice.driver_name}<br/>"
            has_logistics_data = True
        if invoice.driver_phone:
            logistics_details_text += f"Driver Phone: {invoice.driver_phone}<br/>"
            has_logistics_data = True
        if invoice.vehicle_number:
            logistics_details_text += f"Vehicle Number: {invoice.vehicle_number}<br/>"
            has_logistics_data = True
        if invoice.transport_company:
            logistics_details_text += f"Transport Company: {invoice.transport_company}<br/>"
            has_logistics_data = True
        if invoice.lr_number:
            logistics_details_text += f"LR Number: {invoice.lr_number}<br/>"
            has_logistics_data = True
        if invoice.dispatch_date:
            logistics_details_text += f"Dispatch Date: {invoice.dispatch_date.strftime('%d/%m/%Y')}"
            has_logistics_data = True

        # Only show logistics section if there's actual data
        if has_logistics_data:
            logistics_data = [
                [Paragraph(logistics_details_text, normal_style)]
            ]
            logistics_table = Table(logistics_data, colWidths=[180*mm])
            logistics_table.setStyle(TableStyle([
                ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 8),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('TOPPADDING', (0, 0), (-1, -1), 5),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
                ('LEFTPADDING', (0, 0), (-1, -1), 5),
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ]))
            elements.append(logistics_table)
            elements.append(Spacer(1, 3*mm))

    # Footer section - terms and signature (wrapped in KeepTogether for multi-page support)
    terms_text = invoice.terms_and_conditions

    # Build signature section with image if available
    signature_content = []
    signature_content.append(Paragraph(f"<b>For {invoice.company.name}</b>", normal_style))

    # Add signature image if available
    if invoice.company.authorized_signature:
        try:
            signature_path = invoice.company.authorized_signature.path
            if os.path.exists(signature_path):
                signature_img = Image(signature_path, width=40*mm, height=20*mm)
                signature_content.append(Spacer(1, 2*mm))
                signature_content.append(signature_img)
        except Exception as e:
            # If signature image fails to load, just show text
            signature_content.append(Spacer(1, 15*mm))
    else:
        # No signature image, add spacing
        signature_content.append(Spacer(1, 15*mm))

    signature_content.append(Paragraph("Authorized Signatory", normal_style))

    footer_data = [
        [
            Paragraph(f"<b>Terms & Conditions:</b><br/>{terms_text}", normal_style),
            signature_content
        ]
    ]

    footer_table = Table(footer_data, colWidths=[110*mm, 70*mm])
    footer_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('GRID', (0, 0), (-1, -1), 1, colors.black),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 30),
    ]))

    # Computer generated disclaimer
    disclaimer = Paragraph(
        "This is a computer generated invoice and does not require physical signature.<br/>"
        "Generated as per GST Act 2017 | Invoice Template Compliant with CBIC Guidelines",
        ParagraphStyle(
            'DisclaimerStyle',
            parent=styles['Normal'],
            fontSize=7,
            fontName='Helvetica',
            alignment=TA_CENTER,
            textColor=colors.grey,
        )
    )

    # Keep footer together for both layouts
    footer_elements = [
        footer_table,
        Spacer(1, 3*mm),
        disclaimer
    ]
    elements.append(KeepTogether(footer_elements))

    doc.build(elements)
    buffer.seek(0)
    return buffer
