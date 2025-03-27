//title = getTitle();
title = File.nameWithoutExtension;
dir = getDirectory("image");


roiManager("reset");
roiManager("Open", dir+title+"-RoiSet.zip");
roiManager("show all");
waitForUser("Adjust ROIs");
roiManager("Save", dir+title+"-RoiSet.zip");

numROIs = roiManager("count");
for(j = 0; j < numROIs; j++) {
	selectWindow(title+".tif");
	roiManager("Select", j);
	run("Area to Line");
	run("Reslice [/]...", "output=1.000 start=Top avoid");
	run("In [+]");
	run("In [+]");
	run("In [+]");
	rename(title + j + 1);
	saveAs("TIFF", dir + title + "-ROI_" + j + 1);
	Stack.setDisplayMode("color");
	Stack.setChannel(2);
	run("Cyan");
	run("Enhance Contrast", "saturated=0.01");
}
run("Tile");