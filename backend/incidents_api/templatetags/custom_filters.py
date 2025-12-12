from django import template

register = template.Library()

@register.filter(name='as_percentage')
def as_percentage(value, max_value):
    """Convertit une valeur en pourcentage par rapport à une valeur maximale"""
    try:
        value = int(value)
        max_value = int(max_value)
        if max_value == 0:
            return 0
        return int((value * 100) / max_value)
    except (ValueError, TypeError):
        return 0

@register.filter(name='get_item')
def get_item(dictionary, key):
    """Récupère une valeur dans un dictionnaire par sa clé"""
    if not dictionary:
        return key
    return dictionary.get(key, key) 