Dialog.create("CropTop45"); // Creates dialog window with the name "Batch export"
Dialog.addDirectory("Directory:", "");	// Asks for directory to be processed. Copy paste your complete path here
Dialog.addString("Subset (optional):", "ROI_");
Dialog.show();
dir = Dialog.getString();
subset = Dialog.getString();

list = getFileList(dir);
for (i=0; i<list.length; i++) {
	showProgress(i+1, list.length);
	q = dir+list[i];
	if (indexOf(q, subset) >= 0) {
		run("Bio-Formats Windowless Importer", "open=[" + q + "]");
		title = File.nameWithoutExtension;
		makeRectangle(0, 0, 500, 45);
		run("Crop");
		saveAs("TIFF", dir+title+"-crop-top45");
		close();
	}
}

   
