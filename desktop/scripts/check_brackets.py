with open('desktop/lib/features/goals/presentation/goals_page.dart', 'r') as f:
    text = f.read()

def check_brackets(text):
    stack = []
    lines = text.split('\n')
    for i, line in enumerate(lines):
        for j, char in enumerate(line):
            if char in '[{(': 
                stack.append((char, i+1, j+1))
            elif char in ']})':
                if not stack:
                    print(f"Extra closing {char} at line {i+1}")
                    return
                top, l, c = stack.pop()
                expected = {'[': ']', '{': '}', '(': ')'}[top]
                if char != expected:
                    print(f"Mismatch at line {i+1}: expected {expected} to close {top} from line {l}, found {char}")
                    return
    if stack:
        print("Unclosed brackets:")
        for char, l, c in stack:
            print(f"  {char} at line {l}")
    else:
        print("Brackets are balanced.")

check_brackets(text)
