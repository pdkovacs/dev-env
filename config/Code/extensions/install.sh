while read item;
do
    code --install-extension $item
done < <(cat list.txt)
