#!/bin/bash
# Check that all SKILL.md files reference symfony-conventions (except conventions itself)
# Used as a PostToolUse hook on Write|Edit targeting SKILL.md files

FILE_PATH="${TOOL_INPUT_FILE_PATH:-$TOOL_INPUT_file_path}"

# Only check SKILL.md files
if [[ "$FILE_PATH" != *"SKILL.md" ]]; then
  exit 0
fi

# Skip conventions skill itself
if [[ "$FILE_PATH" == *"symfony-conventions"* ]]; then
  exit 0
fi

# Check for the prerequisite line
if ! grep -q "symfony-conventions" "$FILE_PATH"; then
  echo "BLOCKED: This SKILL.md is missing the conventions reference."
  echo "Add this line after the first heading:"
  echo ""
  echo '**Prerequisite**: apply all rules from the `symfony-conventions` skill when writing PHP code.'
  exit 2
fi

exit 0
