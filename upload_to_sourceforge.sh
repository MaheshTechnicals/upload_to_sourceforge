#!/bin/bash

# Function to check if jq is installed
check_dependencies() {
  if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing jq..."
    sudo apt-get update
    sudo apt-get install -y jq
  else
    echo "jq is already installed."
  fi
}

# Check for dependencies (jq)
check_dependencies

# Load credentials and project name from private.json
if [ ! -f private.json ]; then
  echo -e "\e[31mError: private.json not found!\e[0m"
  exit 1
fi

# Read credentials and project name from private.json
SOURCEFORGE_USERNAME=$(jq -r '.username' private.json)
PROJECT_NAME=$(jq -r '.project' private.json)

# Ensure that all required fields are present
if [ -z "$SOURCEFORGE_USERNAME" ] || [ -z "$PROJECT_NAME" ]; then
  echo -e "\e[31mError: Missing required fields in private.json!\e[0m"
  exit 1
fi

# Define the upload path on SourceForge
UPLOAD_PATH="$SOURCEFORGE_USERNAME@frs.sourceforge.net:/home/frs/project/$PROJECT_NAME"

# Find .img and .zip files in the current directory
FILES=($(find . -maxdepth 1 -type f \( -name "*.img" -o -name "*.zip" \)))

if [ ${#FILES[@]} -eq 0 ]; then
  echo -e "\e[31mNo .img or .zip files found to upload.\e[0m"
  exit 1
fi

# Display list of files with numbering and colors
echo -e "\e[1;33mAvailable .img and .zip files for upload:\e[0m"
echo -e "\e[1;32m1)\e[0m \e[34mAll .img and .zip files\e[0m"

for i in "${!FILES[@]}"; do
  echo -e "\e[1;32m$((i+2)))\e[0m \e[36m${FILES[$i]#./}\e[0m"
done

# Prompt user to select files by number (1 for all files)
read -p "Enter the numbers of the files you want to upload (e.g., 2 4 5): " -a selected_numbers

# Function to upload a file
upload_file() {
  local file=$1
  echo -e "\e[34mUploading $file to $UPLOAD_PATH...\e[0m"

  # Use scp to upload the file
  scp "$file" "$UPLOAD_PATH"

  # Check if the upload was successful
  if [ $? -eq 0 ]; then
    echo -e "\e[32mSuccessfully uploaded $file.\e[0m"
  else
    echo -e "\e[31mFailed to upload $file.\e[0m"
  fi
}

# Upload the selected files
for number in "${selected_numbers[@]}"; do
  if [ "$number" -eq 1 ]; then
    # If user selected 1, upload all files
    for file in "${FILES[@]}"; do
      upload_file "$file"
    done
  elif [ "$number" -gt 1 ] && [ "$number" -le $(( ${#FILES[@]} + 1 )) ]; then
    # Upload the specific file
    upload_file "${FILES[$((number-2))]}"
  else
    echo -e "\e[31mInvalid selection: $number\e[0m"
  fi
done

# Verify uploaded files on SourceForge using SSH
echo -e "\e[34mVerifying uploaded files in the project $PROJECT_NAME...\e[0m"

ssh "$SOURCEFORGE_USERNAME@frs.sourceforge.net" "ls /home/frs/project/$PROJECT_NAME"

echo -e "\e[32mUpload and verification process complete.\e[0m"
