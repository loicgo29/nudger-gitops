 cat 1 | cut -d':' -f1 | sort -u|while read file; do  echo -n "$file: "; yq '.metadata.name' "$file"; done >
 find ./infra -name '*helmrelease.yaml' | while read file; do
  echo -n "$file: "; yq '.metadata.name' "$file"
done > helmrelease-liist.txt
