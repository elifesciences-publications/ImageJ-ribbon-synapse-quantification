//Immunohistochem analysis for ribeyeB and MAGUK labeling imaged with Airyscan

//Procedure derived from protocol written by Alisha Beirl, with the addition of watershed
//Candy Wong Oct 19 2018



//How to use:


//Edit the stuff in "A few sample specific param" according to your experiment needs

//In imageJ go to Process>Batch>Macro

//Specify the location of your .lsm files, but leave output blank

//Leave the Output Format and Add Macro Code alone.

//Press Open and select this text file to put it in the white space

//Press Process



//By the way:


//Assumes a few things:

//RibeyeB in one channel, MAGUK in another
//ribeye and MAGUK puncta information are saved in .csv for importing into your favorite spreadsheet program
//A few sample specific parameters
//directories: where to put your images and spreadsheets
    
//you can find the full address of the folder by ctrl+clicking the folder, and click "Get Info"

//***CHANGE TO FOLDER WHERE IMAGES AND DATA ARE SAVED***
    directory_tiff="OUTPUT FILE PATH";
    directory_jpg="OUTPUT FILE PATH";
    directory_spreadsheet="OUTPUT FILE PATH";


    //do you want to save your files with only a part of the .lsm file name? First char is at position 0

    start_position=0;
    remove_from_end=0; //number of characters to take off from the end

    //adding stuff after the .lsm file name
 
    suffix_for_ribB_tiff="";
    suffix_for_ribB_jpg="";

    suffix_for_MAGUK_tiff="";
    suffix_for_MAGUK_jpg="";

    suffix_for_ribB_spreadsheet="_rib_all";
    suffix_for_MAGUK_spreadsheet="_MAGUK_all";

    //channels
    //this script closes extra channel windows at the end with run("Close All")
    //so don't worry about the unused channels
    ch_ribB="C1";
    ch_MAGUK="C3";

	
	
//intensity thresholding for "3D Simple Segmentation" and "Analyze Particle" (in 16-bit)
threshold_ribB_min=20000; //lower number = lower intensity cutoff
threshold_MAGUK_min=15000; //lower number = lower intensity cutoff

rib_cutoff=100; //higher number = lower intensity cutoff
maguk_cutoff=120; //higher number = lower intensity cutoff

//3D Simple Segmentation (size filter may not be working...)
size3D_ribB_min=1; //in voxels?
size3D_MAGUK_min=1;

//Prep for 3D Fast Filter (the peak finder)
//remove the background fluctuations so we don't capture too many extraneous peaks (in 16-bit)
watershed_bg_intensity_ribB=6000; //lower number = more puncta
watershed_bg_intensity_MAGUK=13000; //lower number = more puncta

//3D Fast Filter
filter_type="MaximumLocal";
blob_diameter_ribB=8;  //approximate expected diameter in pixels
blob_depth_ribB=4; //how many planes do blobs occupy
blob_diameter_MAGUK=8;  //approximate expected diameter in pixels
blob_depth_MAGUK=4; //how many planes do blobs occupy

//3D Watereshed (in 16-bit)
//min intensity for peaks found in 3D fast filter
watershed_seeds_intensity_cutoff_ribB=12000; //lower number = more puncta
watershed_image_intensity_cutoff_ribB=1; //min intensity for segmented image. it's binary so took the lowest value = 1.
watershed_seeds_intensity_cutoff_MAGUK=10000; //lower number = more puncta
watershed_image_intensity_cutoff_MAGUK=1; //min intensity for segmented image. it's binary so took the lowest value = 1.

//2D size threshold for "Analyze Particle"
size_ribB_min=0.08; //min area in micron
size_MAGUK_min=0.04; //min area in micron





//That's all!
	run("Set Measurements...", "area mean centroid shape integrated add redirect=None decimal=3"); //"Set measurement" settings

    //Processing starts here!
    title= getTitle();
    name=substring(title,start_position,lengthOf(title)-4-remove_from_end); //also removes the ".lsm"

    ribB_tif="MAX_" + ch_ribB + "-" + name + suffix_for_ribB_tiff + ".tif";
    MAGUK_tif="MAX_" + ch_MAGUK + "-" + name + suffix_for_MAGUK_tiff + ".tif";

    ribB_jpg="MAX_" + ch_ribB + "-" + name + suffix_for_ribB_jpg + ".jpg";
    MAGUK_jpg="MAX_" + ch_MAGUK + "-" + name + suffix_for_MAGUK_jpg + ".jpg";

    ribB_csv=name + suffix_for_ribB_spreadsheet + ".csv";
    MAGUK_csv=name + suffix_for_MAGUK_spreadsheet + ".csv";

    ribB_3D=name + suffix_for_ribB_spreadsheet + "_3D.csv";
    MAGUK_3D=name + suffix_for_MAGUK_spreadsheet + "_3D.csv";
    
    run("Split Channels");

/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*

//     ___  _ __                ___  
//    / _ \(_) /  ___ __ _____ / _ ) 
//   / , _/ / _ \/ -_) // / -_) _  | 
//  /_/|_/_/_.__/\__/\_, /\__/____/__
//   / ___/ /  ___ _/___/___  ___ / /
//  / /__/ _ \/ _ `/ _ \/ _ \/ -_) / 
//  \___/_//_/\_,_/_//_/_//_/\__/_/  
                                 


selectWindow(ch_ribB+"-"+title); 
run("Subtract Background...", "rolling=50 stack");
//small bottleneck

//segmentation routine in a separate stack to not alter intensity in original
run("Duplicate...", "title=segmentation duplicate");
run("Stack Normalizer", "minimum=0 maximum=65000"); //normalize intensity

//find min threshold by measuring total intensity
run("Z Project...", "projection=[Max Intensity]");
run("Set Measurements...", "integrated redirect=None decimal=3"); //temporarily change measurement to min/max
run("Measure");
threshold_ribB=(getResult("IntDen")+450000)/rib_cutoff;
if(threshold_ribB < threshold_ribB_min){
	threshold_ribB = threshold_ribB_min;
}
//print("IntDen = " + getResult("IntDen"));
//print(threshold_ribB);

run("Set Measurements...", "area mean centroid shape integrated add redirect=None decimal=3"); //reset settings
close("MAX_segmentation");

seg_parameters=
  "low_threshold=" + threshold_ribB +
  " min_size=" + size3D_ribB_min +
  " max_size=" + -1; //max_size=-1 means infinity
run("3D Simple Segmentation", seg_parameters);
//this generates 2 windows: "Bin" and "Seg"

//////////generate local maxima for 3D watershed//////////
selectWindow("segmentation");
//run("Gaussian Blur 3D...", "x=2 y=2 z=2");
setMinAndMax(watershed_bg_intensity_ribB, 65535);
run("Apply LUT", "stack");

timeStart = getTime();
filters_parameters=
  "filter=" + filter_type +
  " radius_x_pix=" + d2s(blob_diameter_ribB,1) +
  " radius_y_pix=" + d2s(blob_diameter_ribB,1) +
  " radius_z_pix=" + d2s(blob_depth_ribB,1) +
  " Nb_cpus=8";
run("3D Fast Filters",filters_parameters);
timeEnd = getTime();
durationTimeSec = (timeEnd - timeStart) /1000;
print("3D Fast Filters took " + durationTimeSec + " sec to execute");
//bottleneck
//this generates 1 window: "3D_MaximumLocal"

watershed_parameters=
  "seeds_threshold=" + watershed_seeds_intensity_cutoff_ribB +
  " image_threshold=" + watershed_image_intensity_cutoff_ribB +
  " image=Bin" +
  " seeds=3D_" + filter_type +
  " radius=5";
run("3D Watershed", watershed_parameters);

selectWindow("watershed");
run("Duplicate...", "title=edges duplicate");
run("Maximum 3D...", "x=1 y=1 z=1");
run("Find Edges", "stack");
setMinAndMax(0, 1);
run("Apply LUT", "stack");
imageCalculator("Subtract create stack", "Bin","edges");
selectWindow("Result of Bin");
rename("watershed3D");

//////////get 3D centroid for Ribeye//////////
selectWindow("watershed3D");
run("3D Manager Options", "centroid_(unit) distance_between_centers=10 distance_max_contact=1.80 drawing=Contour");
run("3D Manager");
Ext.Manager3D_Segment(1,65535);
//this generates 1 window: "watershed-3Dseg"
Ext.Manager3D_AddImage();
Ext.Manager3D_Measure();
//This generates 1 results window: "3D Measure" but it's in java so it's invisible to Macro Recorder. 
//Check the 3D suite website for macro instructions
Ext.Manager3D_SaveResult("M",directory_spreadsheet+ribB_3D);
//"M" refers to the window "3D Measure"
Ext.Manager3D_CloseResult("M");
close("watershed3D-3Dseg");
//because of size exclusion during "Analyze particles" the number of total particles will be different
//////////

selectWindow("watershed");
run("Z Project...", "projection=[Max Intensity]");
run("Maximum...", "radius=1");//dilate puncta (in "imageCalculator" edges will cut around instead of on trimming puncta)
run("Find Edges"); //edge detection
setMinAndMax(0, 1); //max all edge intensity
run("Apply LUT");
selectWindow("Bin");
run("Z Project...", "projection=[Max Intensity]");
imageCalculator("Subtract create", "MAX_Bin","MAX_watershed");
//this generates 1 window: Result of MAX_Bin
//MAX_Bin is the final 2D binary image that we can make ROIs out of

selectWindow("Result of MAX_Bin");
run("Make Binary");
run("Invert LUT");
run("Analyze Particles...", "size=&size_ribB_min-Infinity clear add");

close("MAX_Bin");
close("MAX_Seg");
close("Seg");
close("Bin");
close("segmentation");
close("3D_MaximumLocal");
close("watershed");
close("watershed3D");
close("edges");
close("MAX_watershed");
close("Result of MAX_Bin");
Ext.Manager3D_Reset();


//////////apply ROI to original//////////
selectWindow(ch_ribB+"-"+title);
run("Z Project...", "projection=[Max Intensity]");
run("Grays");
run("8-bit");
saveAs("Tiff",  directory_tiff+ribB_tif);
roiManager("Show All with labels");
roiManager("OR"); 
roiManager("Measure");
saveAs("Results", directory_spreadsheet+ribB_csv);
run("Flatten");
run("Input/Output...", "jpeg=100");
saveAs("Jpeg", directory_jpg+ribB_jpg);
close(ribB_jpg); //closing windows
close(ribB_tif);
close("MAX_"+ch_ribB+"-"+name+"-1.tif");
close(ch_ribB+"-"+title);

/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*/////////*

//  __  __   _   ___ _   _ _  __   
// |  \/  | /_\ / __| | | | |/ /   
// | |\/| |/ _ \ (_ | |_| | ' <    
// |_|__|_/_/ \_\___|\___/|_|\_\ _ 
//  / __| |_  __ _ _ _  _ _  ___| |
// | (__| ' \/ _` | ' \| ' \/ -_) |
//  \___|_||_\__,_|_||_|_||_\___|_|
//                                 
//my MAGUK channel

selectWindow(ch_MAGUK+"-"+title);


//segmentation
run("Duplicate...", "title=segmentation duplicate");

//noise filtering
run("Subtract Background...", "rolling=10 stack");
run("Bandpass Filter...", "filter_large=20 filter_small=6 suppress=None tolerance=5 process");
//slight bottleneck both

run("Stack Normalizer", "minimum=0 maximum=65000"); //normalize intensity

//find min threshold by measuring apical noise
run("Z Project...", "stop=1 projection=[Max Intensity]");
//run("Set Measurements...", "min redirect=None decimal=3"); //temporarily change measurement to min/max
run("Set Measurements...", "integrated redirect=None decimal=3"); //temporarily change measurement to min/max
run("Measure");
threshold_MAGUK=getResult("IntDen")/maguk_cutoff;
print("MAGUK threshold: "+threshold_MAGUK);
//getResult("Max")-6000;
if(threshold_MAGUK < threshold_MAGUK_min){
	threshold_MAGUK = threshold_MAGUK_min;
}

run("Set Measurements...", "area mean centroid shape integrated add redirect=None decimal=3"); //reset settings
close("MAX_segmentation");

selectWindow("segmentation");
seg_parameters=
  "low_threshold=" + threshold_MAGUK +
  " min_size=" + size3D_MAGUK_min +
  " max_size=" + -1; //max_size=-1 means infinity
run("3D Simple Segmentation", seg_parameters);
//this generates 2 windows: "Bin" and "Seg"

//////////generate local maxima for 3D watershed//////////
selectWindow("segmentation");
//run("Gaussian Blur 3D...", "x=2 y=2 z=2");
setMinAndMax(watershed_bg_intensity_MAGUK, 65535);
run("Apply LUT", "stack");

timeStart = getTime();
filters_parameters=
  "filter=" + filter_type +
  " radius_x_pix=" + d2s(blob_diameter_MAGUK,1) +
  " radius_y_pix=" + d2s(blob_diameter_MAGUK,1) +
  " radius_z_pix=" + d2s(blob_depth_MAGUK,1) +
  " Nb_cpus=8";
run("3D Fast Filters",filters_parameters);
timeEnd = getTime();
durationTimeSec = (timeEnd - timeStart) /1000;
print("3D Fast Filters took " + durationTimeSec + " sec to execute");
//bottleneck
//this generates 1 window: "3D_MaximumLocal"

watershed_parameters=
  "seeds_threshold=" + watershed_seeds_intensity_cutoff_MAGUK +
  " image_threshold=" + watershed_image_intensity_cutoff_MAGUK +
  " image=Bin" +
  " seeds=3D_" + filter_type +
  " radius=5";
run("3D Watershed", watershed_parameters);

selectWindow("watershed");
run("Duplicate...", "title=edges duplicate");
run("Maximum 3D...", "x=1 y=1 z=1");
run("Find Edges", "stack");
setMinAndMax(0, 1);
run("Apply LUT", "stack");
imageCalculator("Subtract create stack", "Bin","edges");
selectWindow("Result of Bin");
rename("watershed3D");

//////////get 3D centroid for MAGUK//////////
selectWindow("watershed3D");
run("3D Manager Options", "centroid_(unit) distance_between_centers=10 distance_max_contact=1.80 drawing=Contour");
Ext.Manager3D_Segment(1,65535);
//this generates 1 window: "watershed-3Dseg"
Ext.Manager3D_AddImage();
Ext.Manager3D_Measure();
//This generates 1 results window: "3D Measure" but it's in java so it's invisible to Macro Recorder. 
//Check the 3D suite website for macro instructions
Ext.Manager3D_SaveResult("M",directory_spreadsheet+MAGUK_3D);
//"M" refers to the window "3D Measure"
Ext.Manager3D_CloseResult("M");
close("watershed3D-3Dseg");
//////////

selectWindow("watershed");
run("Z Project...", "projection=[Max Intensity]");
run("Maximum...", "radius=1");//dilate puncta (in "imageCalculator" edges will cut around instead of on trimming puncta)
run("Find Edges"); //edge detection
setMinAndMax(0, 1); //max all edge intensity
run("Apply LUT");
selectWindow("Bin");
run("Z Project...", "projection=[Max Intensity]");
imageCalculator("Subtract create", "MAX_Bin","MAX_watershed");


selectWindow("Result of MAX_Bin");
run("Make Binary");
run("Invert LUT");
run("Analyze Particles...", "size=&size_MAGUK_min-Infinity clear add");

close("MAX_Bin");
close("MAX_Seg");
close("Seg");
close("Bin");
close("segmentation");
close("3D_MaximumLocal");
close("edges");
close("watershed");
close("watershed3D");
close("MAX_watershed");
close("Result of MAX_Bin");
Ext.Manager3D_Reset();

//////////apply ROI to original
selectWindow(ch_MAGUK+"-"+title);
run("Z Project...", "projection=[Max Intensity]");
run("Grays");
run("8-bit");
saveAs("Tiff",  directory_tiff+MAGUK_tif);
roiManager("Show All with labels");
roiManager("OR"); 
roiManager("Measure");
saveAs("Results", directory_spreadsheet+MAGUK_csv);
run("Flatten");
run("Input/Output...", "jpeg=100");
saveAs("Jpeg", directory_jpg+MAGUK_jpg);
close(MAGUK_jpg); //closing windows
close(MAGUK_tif);
close("MAX_"+ch_MAGUK+"-"+name+"-1.tif");
close(ch_MAGUK+"-"+title);
run("Close All");
Ext.Manager3D_Close();