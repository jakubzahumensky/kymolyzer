title = getTitle();
dataDir = getDirectory("image");
process_choices = newArray("complete", "export from ROIs");
getDimensions(w, h, channels, slices, frames);
roiManager("reset");

kymoDir = replace(dataDir, "data", "kymograms/");
if (File.exists(kymoDir) == 0) File.makeDirectory(kymoDir);
dir = replace(dataDir, "data", "kymograms/"+title);
if (File.exists(dir) == 0) File.makeDirectory(dir);

q = dir+title+"-corr";
q2 = q+".tif";

Dialog.create("Whatcha doin'?");
	Dialog.addChoice("Image type:", process_choices);
	Dialog.addNumber("Green is channel:", 1);
	Dialog.show();
	process = Dialog.getChoice();
	G = Dialog.getNumber();
	R = 3-G;
	
if (matches(process, "complete")) {
	run("Despeckle", "stack");
	run("Gaussian Blur...", "sigma=1 stack");
	run("Split Channels");
	for (i=1; i<=channels; i++) {
		selectWindow("C"+i+"-"+title);
		run("Bleach Correction", "correction=[Simple Ratio]");
		title2=title+"-C"+i+"-bleach_corr";
		saveAs("TIFF",dir+title2);
		close("C"+i+"-"+title);
		setOption("ScaleConversions", true);
		run("StackReg", "transformation=Translation");
		title3=title2+"-drift_corr";
		saveAs("TIFF",dir+title3);
		if (i == G) rename("Green");
			else rename("Red");
		run("HiLo");	
	}
	
	if (channels == 3) run("Merge Channels...", "c1=C2 c2=C1 c3=C3 create");
	if (channels == 3) run("Merge Channels...", "c1=Green c2=Red c3=C3 create");
	if (channels == 2) run("Merge Channels...", "c1=Green c2=Red create");
	saveAs("TIFF", q);
	
	run("Properties...", "channels=" + channels + " slices=" + frames + " frames=1");
	run("Z Project...", "projection=[Max Intensity]");
	rename("MAX");
	selectWindow(title+"-corr.tif");
	run("Properties...", "channels=" + channels + " slices=1 frames=" + frames);
	N=nImages;
	for (i=1; i<=N; i++){
		selectImage(i);
		for (ch=1; ch<=2; ch++) {
			Stack.setChannel(ch);
			run("Grays");
			run("Enhance Contrast", "saturated=0.01");
			run("In [+]");
			run("In [+]");
		}
		Stack.setDisplayMode("composite");
		Stack.setActiveChannels("110");
	}
	run("Tile");
	selectWindow("MAX");
	setTool("ellipse");
	run("Line Width...", "line=5");
	roiManager("Show All with labels");
	waitForUser("Define ROIs");
	roiManager("Save", q+"-RoiSet.zip");
}

if (matches(process, "export from ROIs")) {
	run("Bio-Formats Windowless Importer", "open=[q2]");
	roiManager("reset");
	roiManager("Open", q+"-RoiSet.zip");
	roiManager("show all");
	waitForUser("Adjust ROIs");
	roiManager("Save", q+"-RoiSet.zip"); 
}

numROIs = roiManager("count");
	for(j=0; j<numROIs;j++) {
		selectWindow(title+"-corr.tif");	
		roiManager("Select", j);
		run("Area to Line");
		run("Reslice [/]...", "output=1.000 start=Top avoid");
		run("In [+]");
		run("In [+]");
		run("In [+]");
		rename(title+j+1);
		saveAs("TIFF", dir+title+"-corr-ROI_"+j+1);
		Stack.setDisplayMode("color");
		Stack.setChannel(1);
		run("Magenta");
		run("Enhance Contrast", "saturated=0.01");
		Stack.setChannel(2);
		run("Cyan");
		run("Enhance Contrast", "saturated=0.01");
	}
run("Tile");
/*
Dialog.create("Crop Top?");
	Dialog.addNumber("Keep top:", 180, 0, 6, "px");
	Dialog.show();
	n = Dialog.getNumber();
	
y=nImages;
for (i=1; i<=y; i++) {
	selectImage(i);
	getDimensions(width, height, channels, slices, frames);
	if (n < height) {
		makeRectangle(0, 0, width, n);
		run("Crop");
	}
}
*/


close("Log");