version = "0.1.0";
setBatchMode(true);

//test = false;
test = true;
if (test == true)
	setBatchMode(false);
	
process_choices = newArray("Create kymograms", "Display kymograms", "Analyze kymograms", "EXIT");
interpolation = newArray("None","Bilinear");
// only files with these extensions will be processed
// if your microscopy images are in a different format, add the extension to the list
var extension_list = newArray("czi", "oif", "lif", "tif", "vsi");
var publication = "Zahumensky & Malinsky, 2004; doi: 10.1093/biomethods/bpae075";
var GitHub_microscopy_analysis = "https://github.com/jakubzahumensky/microscopy_analysis";
var GitHub_kymolyzer = "https://github.com/jakubzahumensky/kymolyzer";

var roiDir = "";
var kymoDir = "";
var kymoDirImage = "";
var kymoDirImageScaled = "";
subset_default = "";

initial_folder = "D:/Yeast/EXPERIMENTAL/macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/230413/";
dialog_window(initial_folder);

function dialog_window(folder){
	help_message = "<html>"
		+"<center><b>Kymolyzer, version "+ version + "</b></center>"
		+"<center><i>source:" + GitHub_kymolyzer + "</i></center>"
		+"<br>"
		+"<b>Create kymograms</b><br>"
		+"Press to create kymograms from defined ROIs. Error is displayed if no ROIs are defined.<br>"
		+"<br>"
		+"<b>Check kymograms</b><br>"
		+"Images in the folder are displayed one-by-one, together with kymograms for each cell (defined ROI). <br>"
		+"<br>"
		+"<b>Analyze kymograms</b><br>"
		+"Kymograms are quantified. Results are saved in a csv file that can be further processed using <i>R scripts</i> published previously (1, 2).<br>"
		+"<br>"
		+"<b>References:</b><br>"
		+"(1) " + publication + "<br>"
		+"(2) " + GitHub_microscopy_analysis + "<br>";
	Dialog.createNonBlocking("Kymolyzer");
		Dialog.addDirectory("Directory:", folder);
		Dialog.addString("Subset (optional):", subset_default);
		Dialog.addChoice("Select an operation:", process_choices);
		Dialog.addHelp(help_message);
		Dialog.show();
		folder = replace(Dialog.getString(), "\\", "/");
		subset = Dialog.getString();
		process = Dialog.getChoice();
	
	processFolder(folder, process);
	dialog_window(folder);
}

function processFolder(dir, processing_function){
    list = getFileList(dir);
    for (i = 0; i < list.length; i++){
        if (endsWith(list[i], "/")) { 
            processFolder("" + dir + list[i], processing_function); // Recursively process subfolders
        } else {
            file = dir + list[i];
//            if (endsWith(dir, image_type + "/data/") && indexOf(file, subset) >= 0) {
            if (endsWith(dir, "/data/") && indexOf(file, subset) >= 0)  {
                extIndex = lastIndexOf(file, ".");
	            ext = substring(file, extIndex+1);
	            if (contains(extension_list, ext)) {
	                title = File.getNameWithoutExtension(file);
	                selectProcessingFunction(processing_function);
	            }
            }
        }
    }
}

function selectProcessingFunction(process){
    if (matches(process, process_choices[0]))
		create_kymograms();
	else if (matches(process, process_choices[1])){
		setBatchMode(false);
		display_kymograms();
	}
	else if (matches(process, process_choices[2]))
		analyze_kymograms();
	else
		exit("See ya.");
}

function prepare(){
	open(file);
	rename(list[i]);
	title = File.nameWithoutExtension;
	rename(title);
	roiDir = File.getParent(dir) + "/" + replace(File.getName(dir), "data", "ROIs") + "/";
	if (!File.exists(roiDir))
		exit("Create ROIs before running this macro again, or double-check the data structure if you have defined ROIs previously.");
	kymoDir = File.getParent(dir) + "/" + replace(File.getName(dir), "data", "kymograms") + "/";
	if (!File.exists(kymoDir))
		File.makeDirectory(kymoDir);
	kymoDirImage = kymoDir + title  + "/";
	if (!File.exists(kymoDirImage))
		File.makeDirectory(kymoDirImage);
	kymoDirImageScaled = kymoDirImage + "scaled/";
	if (!File.exists(kymoDirImageScaled))
		File.makeDirectory(kymoDirImageScaled);
	roiManager("reset");
	roiManager("Open", roiDir + title + "-RoiSet.zip");
	roiManager("Show All with labels");
	roiManager("Remove Channel Info");
}

function create_kymograms(){
	prepare();
	numROIs = roiManager("count");
	init = 0;
	if (test == true)
		init = numROIs - 4;
	for(j = init; j < numROIs; j++) {
		selectWindow(title);	
		roiManager("Select", j);
		run("Area to Line");
		run("Reslice [/]...", "output=1.000 start=Top avoid");
		for (k = 1; k <= 2; k++) {
			Stack.setChannel(i);
			run("Enhance Contrast", "saturated=0.01");
		}
		saveAs("TIFF", kymoDirImage + "ROI_" + j + 1);
//		close();
		rename("kymo");
		for (k = 0; k < 2; k++) {
			run("Scale...", "x=1.0 y=5 z=1.0 depth=2 interpolation=" + interpolation[k] + " average create");
			saveAs("TIFF", kymoDirImageScaled + "ROI_" + j + 1 + "-int_" + interpolation[k]);
			close();
		}
		close("kymo");
	}
	close(title);
}

function display_kymograms(){
	prepare();
	next_image = false;
	scaled = false;
	
	path = kymoDirImage;
	kymoList = getFileList(path);

	while (next_image == false){
		Dialog.createNonBlocking("Select ROIs for display:");
			Dialog.addNumber("From:", 1);
			Dialog.addToSameRow();
			Dialog.addNumber("To:", kymoList.length);
			Dialog.addCheckbox("Scaled:", false);
			Dialog.addCheckbox("Go to next image:", false);
			Dialog.show();
			first = Dialog.getNumber() - 1;
			last = Dialog.getNumber();
			scaled = Dialog.getCheckbox();
			next_image = Dialog.getCheckbox();
			
		close("ROI*");
		
		path = kymoDirImage;
		if (scaled == true)
			path = kymoDirImageScaled;
		kymoList = getFileList(path);
		
		for (j = first; j < last; j++)
			if (!endsWith(kymoList[j], "/"))
				open(path + kymoList[j]);
		run("Tile");		
	}
	close("*");
}

function analyze_kymograms(){
	run("Flip Horizontally", "stack");

}

function contains(array, value){
    for (i = 0; i < array.length; i++)
        if (array[i] == value)
        	return true;
    return false;
}
