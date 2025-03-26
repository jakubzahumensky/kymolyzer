title = getTitle();
dataDir = getDirectory("image");
LUTs = newArray("Green","Red");

process_choices = newArray("complete", "export from ROIs", "load kymos");
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
	correction();
	defineROIs();
	
}


processFolder(dir);

function correction() {
	
if (matches(process, "complete")) {
	run("Despeckle", "stack");
	run("Gaussian Blur...", "sigma=1 stack");
	run("Split Channels");

	selectWindow("C"+G+"-"+title);
		run("Bleach Correction", "correction=[Simple Ratio]");
		close("C"+G+"-"+title);
		setOption("ScaleConversions", true);
		run("StackReg", "transformation=Translation");
		saveAs("TIFF",dir+title+"-C"+G+"-corr");
		rename("Green");
		run("HiLo");
	selectWindow("C"+R+"-"+title);
		for (i=1; i<=frames; i++) run("Duplicate...", "use");
		run("Images to Stack", " ");
		saveAs("TIFF",dir+title+"-C"+R+"-corr");
		rename("Red");
		close("C"+R+"-"+title);
	
	run("Merge Channels...", "c1=Green c2=Red create");
	saveAs("TIFF", q);
	run("Z Project...", "projection=[Max Intensity]");
	rename("MAX");
//to do: rewrite following 6 lines into a for cycle using an array to select LUTs
	for (c=1; c<=2; c++) {
		Stack.setChannel(c);
		run(LUTs[c-1]);
		run("Enhance Contrast", "saturated=0.25");
	}
	run("Maximize");
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

if (matches(process, "load kymos")) {
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
		Stack.setChannel(R);
		run("Magenta");
		run("Enhance Contrast", "saturated=0.5");
		Stack.setChannel(G);
		run("Green");
		run("Enhance Contrast", "saturated=0.5");
		Stack.setDisplayMode("composite");
		Stack.setActiveChannels("11");
		}
}	

run("Tile");
close("Log");