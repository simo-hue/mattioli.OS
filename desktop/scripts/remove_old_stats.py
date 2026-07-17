with open('desktop/lib/features/goals/presentation/goals_page.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if line.startswith('class _GoalStats extends ConsumerWidget {'):
        skip = True
    if skip and line.startswith('class _GoalEditorDialog extends StatefulWidget {'):
        skip = False
    
    if not skip:
        new_lines.append(line)

with open('desktop/lib/features/goals/presentation/goals_page.dart', 'w') as f:
    f.writelines(new_lines)
