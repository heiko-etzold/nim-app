#! /bin/bash

# ## create sticker images and small cube images
# for file in {"woodenCube.png","woddenCubeDark.png","stackableCube.png","stackableCubeDark.png","magicCube.png","magicCubeDark.png"}; do
# 	filename=${file%%.*}
# 	extension=${file##*.}
# 
# 	newfile=$filename"Sticker."$extension
# 	cp $file $newfile
# 	sips --resampleWidth 300 $newfile
# 
# 	for i in {1,2,3}; do
# 		newfile=$filename$i"."$extension
# 		cp $file $newfile
# 		sips --resampleHeight $(($i*40)) $newfile
# 	done
# done
# 
# 
# ## create launch icons
# for file in {"woodenCube.png","woddenCubeDark.png"}; do
# 	filename=${file%%.*}
# 	extension=${file##*.}
# 
# 	for i in {1,2,3}; do
# 		newfile=$filename"Launch$i."$extension
# 		cp $file $newfile
# 		sips --resampleHeight $(($i*300)) $newfile
# 	done
# 
# done


## create app icons

pdfAppIconFile="NimAppIcon.pdf"
pngAppIconFile="NimAppIconTmp.png"
sips -s format png $pdfAppIconfile --out $pngAppIconFile
# tmpMfile="AppIconMTmp.png"
# rawfile="NimAppIconRaw.png"
# rawMfile="AppIconMRaw.png"
# height=`file $file | cut -f 7 -d " " | sed s/x*,//`

# cp $file $tmpfile
# cp $file $tmpMfile
# sips --cropToHeightWidth $((3*$height/2)) $((3*$height/2)) $tmpfile
# sips --cropToHeightWidth $((3*$height/2)) $((2*$height)) $tmpMfile
# pngtopam -background=rgb:ff/ff/ff -mix $tmpfile | pnmtopng - > $rawfile
# pngtopam -background=rgb:ff/ff/ff -mix $tmpMfile | pnmtopng - > $rawMfile

for i in {16,20,29,32,40,58,60,64,76,80,87,120,128,152,167,180,256,512,1024}; do
	pngAppResizedIconFile="NimAppIcon"$i".png"
	cp $pngAppIconFile $pngAppResizedIconFile
	sips --resampleHeight $i $pngAppResizedIconFile
done



pngAppIconMacFile="NimAppIconMac.png"
for i in {16,32,64,128,256,512,1024}; do
	pngAppResizedIconMacFile="NimAppIconMac"$i".png"
	cp $pngAppIconMacFile $pngAppResizedIconMacFile
	sips --resampleHeight $i $pngAppResizedIconMacFile
done





for pngFileIconFile in {"NimLaunchIconLa.png","NimLaunchIconLd.png","NimLaunchIconDa.png","NimLaunchIconDd.png"}; do
    for i in {320,640,940}; do
        pngFileIconResizedFile=$pngFileIconFile$i".png"
        cp $pngFileIconFile $pngFileIconResizedFile
        sips --resampleWidth $i $pngFileIconResizedFile
    done
done

#for i in {22,44}; do
#	pngFileIconResizedFile="NimFileIcon"$i".png"
# 	cp $pngFileIconFile $pngFileIconResizedFile
#	sips --resampleWidth $i $pngFileIconResizedFile
#	sips --cropToHeightWidth $(($i/22*29)) $i $pngFileIconResizedFile
#done





