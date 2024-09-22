#!/bin/bash
    
# Check if the number of commits is provided, default to 10 if not
NUM_COMMITS=${1:-10}

# Initialize an array to collect JSON outputs
json_array=()

# Iterate through the specified number of commits and output the JSON format
while IFS= read -r commit; do
    # Extract the commit message and commit hash
    commit_message=$(echo "$commit" | jq -r '.instruction')
    commit_hash=$(echo "$commit" | jq -r '.commit')

    # Get the previous commit hash
    parent_commit=$(git rev-list --parents -n 1 "$commit_hash" | cut -d' ' -f2)

    # Get the code before the commit (only deleted lines)
    code_before=$(git diff "$parent_commit" "$commit_hash" | grep "^-[^-]" | sed 's/^-//')

    # Get the diff of the commit (showing changes)
    diff=$(git diff "$parent_commit" "$commit_hash")

    # Format the output into clean JSON
    json_out=$(jq -n --arg instruction "$commit_message" --arg input "$code_before" --arg result "$diff" \
        '{
            instruction: $instruction,
            input: ($input | split("\n") | map(. | ltrimstr(" ")) | join("\n")),
            result: $result
        }')

    json_array+=("$json_out")
done < <(git log --pretty=format:'{"instruction": "%s", "commit": "%H"}' -n "$NUM_COMMITS")

# Print the collected JSON objects, joining them with commas
if [ ${#json_array[@]} -gt 0 ]; then
    printf '[%s]\n' "$(IFS=,; echo "${json_array[*]}")"
else
    echo "[]"
fi
