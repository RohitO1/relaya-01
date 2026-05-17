import urllib.request
import json
import time

API_KEY = 'AIzaSyBejm1VyUj9_Y1sC00gzG2JCrr464mJjrU'
URL = f'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={API_KEY}'

vibes = ['Social', 'Personal', 'Dating', 'Networking', 'Roast', 'Deep Talk', '18+']

def fetch_questions(vibe, is_dare, count=200):
    type_str = "dare challenges" if is_dare else "truth questions"
    prompt = f"Generate EXACTLY {count} highly unique, intense, and specific {type_str} for a party game. Vibe: {vibe}. Make them culturally relevant for Indian young adults. Do not use generic questions. Return ONLY a valid JSON array of {count} strings. No markdown formatting, no code blocks, just the JSON array."
    
    data = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 1.0, "maxOutputTokens": 8192}
    }
    
    req = urllib.request.Request(URL, data=json.dumps(data).encode('utf-8'), headers={'Content-Type': 'application/json'})
    
    for _ in range(3):
        try:
            with urllib.request.urlopen(req) as response:
                res = json.loads(response.read().decode())
                text = res['candidates'][0]['content']['parts'][0]['text']
                text = text.replace('```json', '').replace('```', '').strip()
                parsed = json.loads(text)
                if isinstance(parsed, list):
                    return parsed
        except Exception as e:
            print(f"Error fetching {vibe} {type_str}: {e}")
            time.sleep(2)
    return []

def main():
    out_file = "lib/games/truth_dare_data.dart"
    with open(out_file, "w", encoding="utf-8") as f:
        f.write("// GENERATED DATA - DO NOT EDIT MANUALLY\n")
        f.write("class TruthDareData {\n")
        f.write("  static const Map<String, List<String>> truths = {\n")
    
    truth_data = {}
    dare_data = {}
    
    for vibe in vibes:
        print(f"Fetching Truths for {vibe}...")
        truths = fetch_questions(vibe, False, 200)
        # fallback to programmatic generation if API fails or returns too few
        if len(truths) < 50:
            print("Fallback for truths...")
            truths = [f"Truth {vibe} {i}" for i in range(200)]
        truth_data[vibe] = truths
        
        print(f"Fetching Dares for {vibe}...")
        dares = fetch_questions(vibe, True, 200)
        if len(dares) < 50:
            print("Fallback for dares...")
            dares = [f"Dare {vibe} {i}" for i in range(200)]
        dare_data[vibe] = dares

    with open(out_file, "a", encoding="utf-8") as f:
        for vibe, qs in truth_data.items():
            f.write(f"    '{vibe}': [\n")
            for q in qs:
                q_safe = q.replace("'", "\\'").replace('"', '\\"')
                f.write(f"      '{q_safe}',\n")
            f.write("    ],\n")
        f.write("  };\n\n")
        
        f.write("  static const Map<String, List<String>> dares = {\n")
        for vibe, qs in dare_data.items():
            f.write(f"    '{vibe}': [\n")
            for q in qs:
                q_safe = q.replace("'", "\\'").replace('"', '\\"')
                f.write(f"      '{q_safe}',\n")
            f.write("    ],\n")
        f.write("  };\n")
        f.write("}\n")

if __name__ == "__main__":
    main()
