import sys

def distinguish_char(input_string):
    char_map = {
        'l': 'lowercase L',
        '1': 'digit 1',
        'i': 'lowercase I',
        'I': 'capital I',
        'o': 'lowercase O',
        'O': 'capital O',
        '0': 'digit 0',
        'k': 'lowercase K',
        'K': 'capital K'
    }

    result = []
    for char in input_string:
        if char in char_map:
            result.append(f"{char}[{char_map[char]}]")
        else:
            result.append(char)
    return''.join(result)

if len(sys.argv) < 2:
    print("Usage: python ellpass.py <input_string>")
    sys.exit(1)

input_string = sys.argv[1]
output = distinguish_char(input_string)

print(output)    