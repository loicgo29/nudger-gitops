DIR=$HOME/nudger-gitops
find $DIR -type f  -name '*helmrelease.yaml' | while read file; do
  echo -n "$file: "; yq '.metadata.name' "$file"
echo
done > helmrelease-list1.txt
grep -nR HelmRelease --include="*.yaml" $DIR  |cut -d':' -f1 | sort -u|while read file; do 
  echo -n "$file "
done > helmrelease-list2.txt
cat helmrelease-list1.txt  helmrelease-list2.txt |sort -u > helmrelease-liist.txt
