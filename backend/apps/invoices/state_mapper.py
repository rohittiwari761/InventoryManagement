"""
State name normalization for inter-state invoice detection.
Handles variations and abbreviations of Indian state names.
"""

# Mapping of state variations to normalized names
STATE_MAPPING = {
    # Andhra Pradesh
    'andhra pradesh': 'andhra pradesh',
    'ap': 'andhra pradesh',
    'andhra': 'andhra pradesh',

    # Arunachal Pradesh
    'arunachal pradesh': 'arunachal pradesh',
    'arunachal': 'arunachal pradesh',
    'ar': 'arunachal pradesh',

    # Assam
    'assam': 'assam',
    'as': 'assam',

    # Bihar
    'bihar': 'bihar',
    'br': 'bihar',

    # Chhattisgarh
    'chhattisgarh': 'chhattisgarh',
    'chattisgarh': 'chhattisgarh',
    'cg': 'chhattisgarh',
    'ct': 'chhattisgarh',

    # Goa
    'goa': 'goa',
    'ga': 'goa',

    # Gujarat
    'gujarat': 'gujarat',
    'gj': 'gujarat',

    # Haryana
    'haryana': 'haryana',
    'hr': 'haryana',

    # Himachal Pradesh
    'himachal pradesh': 'himachal pradesh',
    'himachal': 'himachal pradesh',
    'hp': 'himachal pradesh',

    # Jharkhand
    'jharkhand': 'jharkhand',
    'jh': 'jharkhand',

    # Karnataka
    'karnataka': 'karnataka',
    'ka': 'karnataka',
    'kn': 'karnataka',

    # Kerala
    'kerala': 'kerala',
    'kl': 'kerala',

    # Madhya Pradesh
    'madhya pradesh': 'madhya pradesh',
    'madhya': 'madhya pradesh',
    'mp': 'madhya pradesh',

    # Maharashtra
    'maharashtra': 'maharashtra',
    'mh': 'maharashtra',

    # Manipur
    'manipur': 'manipur',
    'mn': 'manipur',

    # Meghalaya
    'meghalaya': 'meghalaya',
    'ml': 'meghalaya',
    'meg': 'meghalaya',

    # Mizoram
    'mizoram': 'mizoram',
    'mz': 'mizoram',

    # Nagaland
    'nagaland': 'nagaland',
    'nl': 'nagaland',

    # Odisha
    'odisha': 'odisha',
    'orissa': 'odisha',
    'od': 'odisha',
    'or': 'odisha',

    # Punjab
    'punjab': 'punjab',
    'pb': 'punjab',

    # Rajasthan
    'rajasthan': 'rajasthan',
    'rj': 'rajasthan',

    # Sikkim
    'sikkim': 'sikkim',
    'sk': 'sikkim',

    # Tamil Nadu
    'tamil nadu': 'tamil nadu',
    'tamilnadu': 'tamil nadu',
    'tn': 'tamil nadu',

    # Telangana
    'telangana': 'telangana',
    'ts': 'telangana',
    'tg': 'telangana',

    # Tripura
    'tripura': 'tripura',
    'tr': 'tripura',

    # Uttar Pradesh
    'uttar pradesh': 'uttar pradesh',
    'up': 'uttar pradesh',

    # Uttarakhand
    'uttarakhand': 'uttarakhand',
    'uttaranchal': 'uttarakhand',
    'uk': 'uttarakhand',
    'ua': 'uttarakhand',

    # West Bengal
    'west bengal': 'west bengal',
    'wb': 'west bengal',

    # Union Territories
    'andaman and nicobar islands': 'andaman and nicobar islands',
    'andaman': 'andaman and nicobar islands',
    'an': 'andaman and nicobar islands',

    'chandigarh': 'chandigarh',
    'ch': 'chandigarh',

    'dadra and nagar haveli and daman and diu': 'dadra and nagar haveli and daman and diu',
    'dadra and nagar haveli': 'dadra and nagar haveli and daman and diu',
    'daman and diu': 'dadra and nagar haveli and daman and diu',
    'dadra': 'dadra and nagar haveli and daman and diu',
    'daman': 'dadra and nagar haveli and daman and diu',
    'dnh': 'dadra and nagar haveli and daman and diu',
    'dd': 'dadra and nagar haveli and daman and diu',
    'dn': 'dadra and nagar haveli and daman and diu',

    'delhi': 'delhi',
    'new delhi': 'delhi',
    'dl': 'delhi',

    'jammu and kashmir': 'jammu and kashmir',
    'jammu': 'jammu and kashmir',
    'kashmir': 'jammu and kashmir',
    'jk': 'jammu and kashmir',
    'j&k': 'jammu and kashmir',

    'ladakh': 'ladakh',
    'la': 'ladakh',

    'lakshadweep': 'lakshadweep',
    'ld': 'lakshadweep',

    'puducherry': 'puducherry',
    'pondicherry': 'puducherry',
    'py': 'puducherry',
}


def normalize_state_name(state_name):
    """
    Normalize state name to handle variations and abbreviations.

    Args:
        state_name (str): State name or abbreviation

    Returns:
        str: Normalized state name in lowercase

    Examples:
        >>> normalize_state_name('Delhi')
        'delhi'
        >>> normalize_state_name('DL')
        'delhi'
        >>> normalize_state_name('Maharashtra')
        'maharashtra'
        >>> normalize_state_name('MH')
        'maharashtra'
    """
    if not state_name:
        return ''

    # Convert to lowercase and strip whitespace
    normalized = state_name.lower().strip()

    # Remove extra spaces
    normalized = ' '.join(normalized.split())

    # Look up in mapping
    return STATE_MAPPING.get(normalized, normalized)
