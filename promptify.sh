#!/bin/bash

# Usage: ./promptify.sh <num_commits>
# 
# This script processes the last num_commits (default: 10) from a git repository
# and generates a JSON array with details of each commit. The details include:
# - The commit message (as 'instruction').
# - The lines of code removed before the commit (as 'input').
# - The full diff between the current and previous commit (as 'result').
#
# The script assumes that the git repository is in the current directory.
# The script requires 'jq' to be installed to parse JSON data.
# The script follows the Alpaca prompt format for the JSON output.
#
# The JSON array is printed to stdout, where each object has the following structure:
# {
#   "instruction": "commit message",
#   "input": "code before the commit",
#   "result": "full diff"
# }
#
# Arguments:
#   num_commits: (Optional) The number of commits to process (default: 10).
    
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

    # Get the diff of the commit, filtering by the provided file pattern (if any)
    if [ -n "$FILE_FILTER" ]; then
        diff=$(git diff "$parent_commit" "$commit_hash" -- "$FILE_FILTER")
    else
        diff=$(git diff "$parent_commit" "$commit_hash")
    fi

    # If the diff is empty (no changes matching the file filter), skip this commit
    if [ -z "$diff" ]; then
        continue
    fi

    # Get the code before the commit (only deleted lines, filtered by file if provided)
    if [ -n "$FILE_FILTER" ]; then
        code_before=$(git diff "$parent_commit" "$commit_hash" -- "$FILE_FILTER" | grep "^-[^-]" | sed 's/^-//')
    else
        code_before=$(git diff "$parent_commit" "$commit_hash" | grep "^-[^-]" | sed 's/^-//')
    fi
    
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
