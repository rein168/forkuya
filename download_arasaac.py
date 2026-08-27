import urllib.request
import json
import os
import time

words = [
    'MORE', 'DONE', 'HELP', 'STOP', 'GO', 'YES', 'NO', 'WANT', 'LIKE',
    'APPLE', 'BANANA', 'COOKIE', 'MILK', 'WATER', 'BREAD', 'PIZZA', 'CHEESE', 'JUICE', 'CRACKER',
    'DOG', 'CAT', 'BIRD', 'FISH', 'COW', 'PIG', 'HORSE', 'FROG', 'LION', 'BEAR',
    'RED', 'BLUE', 'GREEN', 'YELLOW', 'BLACK', 'WHITE', 'ORANGE', 'PURPLE', 'PINK', 'BROWN',
    'BALL', 'CAR', 'DOLL', 'BLOCK', 'BOOK', 'PUZZLE', 'BUBBLES', 'TRAIN', 'TEDDY',
    'EYES', 'EARS', 'NOSE', 'MOUTH', 'HANDS', 'FEET', 'HEAD', 'HAIR'
]

os.makedirs('assets/symbols', exist_ok=True)

for word in words:
    clean_word = word.lower()
    print(f'Fetching {clean_word}...')
    try:
        req = urllib.request.Request(f'https://api.arasaac.org/api/pictograms/en/search/{clean_word}', headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            if data:
                img_id = data[0]['_id']
                img_url = f'https://static.arasaac.org/pictograms/{img_id}/{img_id}_300.png'
                
                img_req = urllib.request.Request(img_url, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(img_req) as img_resp:
                    with open(f'assets/symbols/{clean_word}.png', 'wb') as f:
                        f.write(img_resp.read())
                print(f'Saved {clean_word}.png')
            else:
                print(f'Not found: {clean_word}')
    except Exception as e:
        print(f'Error for {clean_word}: {e}')
    time.sleep(0.1)

