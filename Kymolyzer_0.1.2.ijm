version = "0.1.2";
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

var file = "";
var roiDir = "";
var kymoDir = "";
var kymoDirImage = "";
var kymoDirImageScaled = "";
subset_default = "";

//initial_folder = "D:/Yeast/EXPERIMENTAL/macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/230413/";
initial_folder = "D:/Yeast/EXPERIMENTAL/macros/JZ-IJ-004 - Kymolyzer/test_images/JZ-M-064/";
dialog_window(initial_folder);

function dialog_window(folder){
	help_message = "<html>"
		+"<center><b>Kymolyzer, version "+ version + "</b></center>"
		+"<center><i>source:" + GitHub_kymolyzer + "</i></center>"
		+"<br>"
		+"<i> This macro requires that ROIs are already defined and named a certain way that corresponds to guidelines in (1). "
		+"It is strongly recommended that the provided 'Correct and project' macro is used to prepare the images first, "
		+"followed by the 'ROI_prep' macro to make the actual ROIs.</i><br>"
		+"<br>"
		+"<b>Create kymograms</b><br>"
		+"Press to create kymograms from defined ROIs. Error is displayed if no ROIs are defined.<br>"
		+"<br>"
		+"<b>Check kymograms</b><br>"
		+"Images in the folder are displayed one-by-one, together with kymograms for each cell (defined ROI).<br>"
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
		Dialog.setLocation(screenWidth*2.04/3, screenHeight/9.5);
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
        if (endsWith(list[i], "/")){ 
            processFolder("" + dir + list[i], processing_function); // Recursively process subfolders
        } else {
            file = dir + list[i];
//            if (endsWith(dir, image_type + "/data/") && indexOf(file, subset) >= 0){
            if (endsWith(dir, "/data/") && indexOf(file, subset) >= 0){
                extIndex = lastIndexOf(file, ".");
	            ext = substring(file, extIndex+1);
	            if (contains(extension_list, ext)) {
	                title = File.getNameWithoutExtension(file);
	                i = selectProcessingFunction(processing_function, i);
	            }
            }
        }
    }
}

function selectProcessingFunction(process, i){
    if (matches(process, process_choices[0]))
		i = create_kymograms(i);
	else if (matches(process, process_choices[1])){
		setBatchMode(false);
		i = display_kymograms(i);
	}
	else if (matches(process, process_choices[2]))
		i = analyze_kymograms(i);
	else
		exit("See ya.");
	return i;
}

function prepare(){
	open(file);
	setLocation(0, 0);
	title = File.nameWithoutExtension;
	rename(title);
	roiDir = File.getParent(dir) + "/" + replace(File.getName(dir), "data", "ROIs") + "/";
	if (!File.exists(roiDir))
		exit("Create ROIs before running this macro again, or double-check the data structure if you have defined ROIs previously.");
	kymoDir = File.getParent(dir) + "/" + replace(File.getName(dir), "data", "kymograms") + "/";
	kymoDirImage = kymoDir + title  + "/";
	kymoDirImageScaled = kymoDirImage + "scaled/";
	dirList = newArray(kymoDir, kymoDirImage, kymoDirImageScaled);
	for (j = 0; j < dirList.length; j++)
		if (!File.exists(dirList[j]))
			File.makeDirectory(dirList[j]);
	roiManager("reset");
	roiManager("Open", roiDir + title + "-RoiSet.zip");
	roiManager("Show All with labels");
	roiManager("Remove Channel Info");
}

function create_kymograms(l){
// TODO - some renaming magic will need to take place here
// otherwise the ROI handling will be cumbersome and require the user to rename things
// maybe search for SUM/MAX/AVG in ROISet names and remove them?
	prepare();
	numROIs = roiManager("count");
	last = numROIs;
	if (test == true)
		last = 5;
	for (j = 0; j < last; j++) {
		selectWindow(title);	
		roiManager("Select", j);
		run("Area to Line");
		run("Reslice [/]...", "output=1.000 start=Top avoid");
		for (k = 1; k <= 2; k++) {
			Stack.setChannel(i);
			run("Enhance Contrast", "saturated=0.01");
		}
		saveAs("TIFF", kymoDirImage + "ROI_" + j + 1);
		rename("kymo");
		for (k = 0; k < 2; k++) {
			run("Scale...", "x=1.0 y=5 z=1.0 depth=2 interpolation=" + interpolation[k] + " average create");
			saveAs("TIFF", kymoDirImageScaled + "ROI_" + j + 1 + "-int_" + interpolation[k]);
			close();
		}
		close("kymo");
	}
	close(title);
	return l;
}

function display_kymograms(k){
	prepare();

	kymoPath = kymoDirImage;
	kymoList = getFiles(kymoPath);
	kymo_count = kymoList.length;
	list_plus = Array.concat("previous image", "this image", "next image", list);
	display_next = "this image";
	while (display_next == "this image"){
		Dialog.createNonBlocking("Select ROIs for display:");
			Dialog.addString("Kymograms to display:", 1 + "-" + kymo_count);
			Dialog.addChoice("Display", newArray("regular","scaled"));
			Dialog.addMessage("current image: " + list[k]);
			Dialog.addMessage("Image:" + k+1 + "/" + list.length);
			Dialog.addChoice("Display next:", list_plus, "this image");
			Dialog.setLocation(screenWidth*2.07/3, screenHeight*6.7/9);
			Dialog.show();
			kymograms = Dialog.getString();
			display_type = Dialog.getChoice();
			display_next = Dialog.getChoice();		
	
		if (display_next != "this image")
			break;
		
		kymogram_IDs = sort_IDs(kymograms, kymoList.length);
		close("ROI*");
	
		kymoPath = kymoDirImage;
		if (display_type == "scaled"){
			kymoPath = kymoDirImageScaled;
			for (j = 0; j < kymogram_IDs.length; j++)
				kymogram_IDs[j] = kymogram_IDs[j]*2;
		}
		kymoList = getFiles(kymoPath);
		for (j = 0; j < kymogram_IDs.length; j++){
			l = kymogram_IDs[j]-1;
			open(kymoPath + kymoList[l]);
		}
		run("Tile");
	}
	
	close("*");
	if (display_next == "previous image"){
		if (k > 0){
			k--;
		} else {
			display_next = "this image";
			waitForUser("This is the first image of the series, there is no previous image.");
		}
	} else if (display_next == "next image"){
		k++;
		if (k >= list.length)
			return k-1;
	} else {
		k = getIndex(list, display_next);
	}
	return k-1;
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

function getIndex(array, value){
    for (i = 0; i < array.length; i++) 
        if (array[i] == value)
        	return i;
    return "not in array";
}

function getFiles(path){
	list = getFileList(path);
	for (i = list.length-1 ; i >= 0 ; i--){
		if (endsWith(list[i], "/"))
			list = Array.deleteIndex(list, i);
	}
	return list;
}

function sort_IDs(string, integer){
	// if a range is defined, use the lower number as the beginning and the higher as end value; create an array containing these and all integer numbers between them
	string = replace(string, " ", "");
	array = split(string,",,");
	array_temp = newArray(0);
	for (i = array.length-1; i >= 0; i--){
		if (indexOf(array[i], "-") >= 0){
			string_temp = split(array[i],"--");
			string_temp = Array.sort(string_temp);
			for (k = string_temp[0]; k <= string_temp[1]; k++){
				array_temp = Array.concat(array_temp, k);
			}
			array = Array.deleteIndex(array, i);
		}
	}
	// concatenate arrays and turn all items into integers (one of the things above creates strings)
	// substitute out of bounds values with nearest valid input (safety measure to avoid errors and macro crash)
	array = Array.concat(array, array_temp);
	for (i = 0; i < array.length; i++){
		array[i] = parseInt(array[i]);
		if (array[i] > kymoList.length)
			array[i] = kymoList.length;
		if (array[i] < 1)
			array[i] = 1;
	}
	// sort array in ascending order and remove duplicates from the list of ROIs to be display to avoid displaying same ROI multiple times
	// used algorithm for removal of duplicates requires a sorted array
	array = Array.sort(array); 
	if (array.length > 1){
		for (i = array.length-2; i >= 0; i--){
			if (array[i] == array[i+1])
				array = Array.deleteIndex(array, i);
		}
	}
	return array;
}
