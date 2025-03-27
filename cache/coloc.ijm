title = getTitle();
title2 = File.nameWithoutExtension;
title3 = substring(title2,0,lengthOf(title2)-1);
dir = getDirectory("image");
y=nImages;
for (i=1; i<=y; i++) {
	selectWindow(title3+i+".tif");
	title=getTitle();
	run("Split Channels");
	run("Colocalization Threshold", "channel_1=C1-"+title+" channel_2=C2-"+title+" use=None channel=[Red : Green] include");
}
close("*");