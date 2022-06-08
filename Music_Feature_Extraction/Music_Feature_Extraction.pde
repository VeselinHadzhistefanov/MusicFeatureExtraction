import ddf.minim.*;            //This project uses the Minim audio librarly availabe from the processing website to open and manipulate audio files 
import ddf.minim.analysis.*;  
import ddf.minim.spi.*;        
import ddf.minim.ugens.*;  


Minim minim;          //Creates an instance of a minim object needed for opening and processing audio files
AudioOutput out;      //Creates and instance of an AudioOutput which enable the program to output audio information
Sampler instrument;   //An object that will be used to store and playback audio data.

Constant pitch;       
Constant amp;         //Mimin specific objects that are used as variables for certain methods (Minim requires these objects to be used instead of regular float and int variables)



float [][] frames;         //A variable that is used to store consecutive frames of the analysis and represent the amplitudes that are detected at different frequencies. 
                           //The first index corresponds to the the frame (Fourier analysis splits the audio into small segments and analyses them independently)
                           //and the second coresponds to the different frequencies in the Fourier analysis
                       
float [][] logFrames;      //A variable used to store the same information in log format

float [][] peaks;          //A variable used to store only the strongest frequencies detected with the analysis 

float [][] harmony;        // A variable used to represent how strong certain pitches are compared to others
float [][] notes;          // A variable used to store the notes detected in the analised file.
float [][] originalNotes;  

float [][] harmonizedNotes;



PImage framesImg;          //used to display the analysis frames
PImage notesImg;           //used to display the notes

String instrumentPath;    //the file path for the instrument 
int instrumentPitch;      //variable for the pitch of the instrument
int sourceRoot;           //variable for most prominent pitch in the source file

int currentInstrument;    
int currentSource;        //varibles that store which instrument/source is curently in use
int moreData = 0;         
int snapMode = 0;         // Variable for the display and note options


String[] sourcePaths = { "jazzguitar2_3.mp3", "guitar1.wav", "guitarnotes2.wav", "violin1.wav", "sax1.wav", "piano2.mp3" };

String[] sourceNames = {"Notes 1", "Notes 2", "Notes 3", "Notes 4", "Notes 5", "Notes 6"};

String[] instrumentPaths = { "pianonote3_2.mp3", "guitarPluck_2.mp3", "chime1.wav", "violin.wav", "tanbura2.aiff", "guitarPluck_2.mp3"};

String[] instrumentNames = { "Piano", "Guitar", "Chime", "Violin", "Tambura", ""};

String[] noteNames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};

String[] snapNames = {"Major Scale", "Minor Scale", "Chromatic"};


AudioSample sample;  //variable used to store a sample of audio
FFT fft;             // A Mimin variable used for the analysis of the audio data
int fftSize;         //Variable for the size of the FFT
int totalFrames;     // Variable for the number of frames

int arraySize;       //A variable for the log representaion of the analysis data 

float frameIdx = 0;  //An index that controls the playback of the audio




void setup(){
  size(600,400);
  colorMode(HSB,100);
  
  
  minim = new Minim(this);
  out   = minim.getLineOut();
  
  currentInstrument = 0;
  
  pitch = new Constant(1);
  amp = new Constant(0.2);       //initialise Minim components
  
  instrument = new Sampler( instrumentPaths[0], 24, minim );
  
  pitch.patch(instrument.rate);  
  amp.patch(instrument.amplitude);  
  instrument.patch(out);
   
  getSampleData(instrumentPaths[0]);  //load and analyse data from the first instrument sample
  instrumentPitch = getRoot(notes);  
  
  
  
  getSampleData(sourcePaths[0]);      //load and analyse data from the first source sample
  sourceRoot = getRoot(notes);
  
  originalNotes = new float[notes.length][120];
  arrayCopy(notes, originalNotes, notes.length);
  
  harmonizedNotes = harmonize(originalNotes, sourceRoot, snapMode);  //Display the notes detected on the screen
  drawNotes();
  drawFrames();
  

  
  
  
  frameRate(sample.sampleRate()/fftSize);
  
}


void drawNotes(){  
  
  notesImg = createImage(originalNotes.length, 120, ARGB);       //This method is used to draw the notes from the notes array onto the notesImg variable
  
  for(int i = 0; i < originalNotes.length; i++){
    for(int k = 0; k < 120; k++){
        if (k >= 48){
          if( harmonizedNotes[i][k] > 0 ) notesImg.set(i, 120-k, color(55,50,50, 100));
          else notesImg.set(i, 120-k, color(0,0,0,0));
        }
        else if(moreData == 1){
          if( harmonizedNotes[i][k] > 0 ) notesImg.set(i, 120-k, color(55,0,50, 50));
          else notesImg.set(i, 120-k, color(0,0,0,0));
        
        }
        
    }
  }
  notesImg.resize(600, 300);
  
  
    

}

void drawFrames(){ 

  framesImg = createImage(totalFrames, arraySize, ARGB);        //This method is used to draw the frames data onto an image variable
  
  for(int i = 0; i < totalFrames; i++){
    for(int k = 0; k < arraySize; k++){
      float amp = 20 * log10(logFrames[i][k]);
      if( amp > 0 ) framesImg.set(i, arraySize-k, color(44,50,50, amp*4));
      else framesImg.set(i, arraySize-k, color(0,0,0,0));
    }
  }  
  framesImg.resize(600, 300);


}





float[][] harmonize(float[][] notesArray, int root, int scale){
  
  root = root % 12; 

  int[][] scales ={ {1,0,1,0,1,1,0,1,0,1,0,1}, {1,0,1,1,0,1,0,1,1,0,1,0} };      //This method is used to harmonize the notes to the selected scale
  
  float[][] newNotes = new float[notesArray.length][120];
  if(scale < 2){
    for(int i = 0; i < notesArray.length; i++){
      for(int k = 0; k < 120; k++){
        int noteFromScale = (k%12 - root + 12) % 12;
        
        if(notesArray[i][k] > 0 && scales[scale][noteFromScale] == 0 ){
          newNotes[i][k+1] = notesArray[i][k];
        }
        else if(newNotes[i][k] == 0) newNotes[i][k] = notesArray[i][k];
        
      }
      
    }
  }
  else newNotes = notesArray;
  
  
  return newNotes;

}


int getRoot(float[][] notesArray){       //This method is used to detect the most common pitch in an array of notes
  
  float max = 0;
  int maxIdx = 0;
  for(int i = 0; i < 120; i++){
    float sum = 0;
    for(int k = 0; k < notesArray.length; k++){
      sum += notesArray[k][i]/notesArray.length;
    }
    if(sum > max){
      max = sum;
      maxIdx = i;
    }
    
    
  }


  return maxIdx;

}







void getSampleData(String filePath){ 
  
  
  

  sample = minim.loadSample(filePath, 2048);  
  float[] audioSamples = sample.getChannel(sample.LEFT);        //Load audio data into the audioSamples variable
  
  fftSize = 2048;   
  fft = new FFT(fftSize, sample.sampleRate());
  fft.window( FFT.HANN );
  
  totalFrames = audioSamples.length/fftSize;  
  frames = new float[totalFrames][fftSize/2];  
  

  
  

  
  
  float[] audioFrame = new float[fftSize];         
  
  for(int i = 0; i < totalFrames; i++){                    //Copy data from the audioSamples variable
    int frameStart = i*fftSize;
    arrayCopy(audioSamples, frameStart, audioFrame, 0, fftSize);
    
    fft.forward(audioFrame);              //Analyse the data

    for(int k = 0; k < fftSize/2; k++){    //save the analysis in the frames variable
      frames[i][k] = fft.getBand(k);          
    }

  }   
  
  
  
  arraySize = 600;
  float[][]peaks = new float[totalFrames][arraySize]; 
  float[] meanAmp = new float[totalFrames];                
  
  float SR = sample.sampleRate();
  
  for(int i = 0; i < totalFrames; i++){

    for(int k = 1; k < fftSize/2-1; k++){
      float x1 = frames[i][k-1];
      float x2 = frames[i][k]; 
      float x3 = frames[i][k+1];
      
      if(x1<x2 && x2>x3){                         //detect a peak where there is a single strong frequency with weak frequencies next to it
        float offset =(x1-x3)/((x1-2*x2+x3)*2);
        
        float frequency = (k+offset)*SR/fftSize;        
        float amplitude = x2 - (x1-x3)*offset/4;  //detect the exact frequency by quadratically interpolating between the values of the frequencies
       
        float pitch = getPitch(frequency);     //convert the detected frequncy to pitch ( Pitch is used to represent notes)
         
        int n = (int)(float)((pitch - getPitch(22))*5);  
        
        if(n >= 0 && n <= arraySize-1) peaks[i][n] = amplitude; //store the amplitude in the peaks array
        
      }   
      
      
    }   
    meanAmp[i] = getMean(peaks[i]); //detect the mean amplidude
  }
  
  

  logFrames = new float[totalFrames][arraySize]; //Transform the data from the analysis frames into log format
  
  float minPitch = getPitch(SR/fftSize);
  float maxPitch = getPitch(SR/2);
  
  for(int i = 0; i < totalFrames; i++){
    for(int k = 1; k < arraySize-1; k++){
      
      float pitch = getPitchFromIdx(k);
      if(pitch-0.1 > minPitch && pitch+0.1 < maxPitch){
        
        float idx1 = fftSize/(SR / getFrequency(pitch-0.1));
        float idx2 = fftSize/(SR / getFrequency(pitch+0.1));
        float sum = 0;
        int count = 0;
     
        for(int idx  = (int)idx1; idx < idx2; idx++){
          count++;
          sum += frames[i][idx];      
        }
        
        logFrames[i][k] = sum/count;
     
      }
      
    }

  }
  

  
  
  
  harmony = new float[totalFrames][arraySize]; 
  
  for(int i = 0; i < totalFrames; i++){            //detect the pitches that seem harmonious with other pitches
      for(int j = 0; j < arraySize; j++){
        
        if(peaks[i][j] > meanAmp[i]){
          float match = 0;
          float idxFrequency = getFrequency(getPitchFromIdx(j));
          
          for(int k = j; k < arraySize; k++){   
            
            float matchFrequency = getFrequency(getPitchFromIdx(k));            
            float factor = matchFrequency/idxFrequency;
            
            match += pow(1+cos(TWO_PI*abs(round(factor)-factor)), 8) * peaks[i][k];
          }
          
          harmony[i][j] = 20 * log10(match);
          
        
        }
  
      }
  }
  
  notes = new float[totalFrames][120]; //Copy the  notes that are going to be played
  
  int lowestPitch = 36;
  
  for(int i = 0; i < totalFrames; i++){
    for(int j = lowestPitch; j < lowestPitch + 48; j++){  
      int idx = (int)getIdxFromPitch(j);
      float sum = 0;
      for(int k = -2; k <=2; k++) sum += harmony[i][idx+k]; 
      
      notes[i][j] = sum; 
    }  
  }
  
  for(int i = 1; i < totalFrames-1; i++){
    for(int j = lowestPitch; j < lowestPitch + 48; j++){ 
      if( abs(notes[i-1][j] - notes[i+1][j]) <= notes[i-1][j]/10) notes[i][j] = (notes[i-1][j] + notes[i+1][j])/2; 
      
      if(notes[i-1][j] < notes[i][j]/10){
        int count = 0;
        int check = 0;
        while (check == 0 && count < 4){
          if (notes[i+count][j] < notes[i][j]/10) check = 1; 
          count++;
          if (i+count >= totalFrames-1) check = 1;
          
        }
        if(check == 1) {
          for(int k = 0; k < count; k++) {
            notes[i+k][j] = 0;
          }
        }
        
      
      }
    
    
    }
  }
  
  
 
  

  

  
  

  
  
  

}

//log10-------------------------------------------------------------------
float log10 (float x) {
  return (log(x) / log(10));
}

//getPitch-------------------------------------------------------------------
float getPitch(float frequency){  
  return 69+12*log(frequency/440)/log(2);  
}

//getFrequency-------------------------------------------------------------------
float getFrequency (float pitch){  
  return 440 * pow(2, (pitch-69)/12);
}

//getPitchFromIdx------------------------------------------------------------------
float getPitchFromIdx (float idx){
  return idx/5 + getPitch(22);
}

//getIdxFromPitch------------------------------------------------------------------
float getIdxFromPitch (float pitch){
  return (pitch - getPitch(22)) * 5;
}

//getMean--------------------------------------------------------------------------------
float getMean(float[] array){
  
  float total = 1;
  float weight = 0;
  
  for(int i = 0; i < array.length; i++){    
     float amp = array[i];
     total += amp;
     
     weight = amp*amp/total + weight*(total-amp)/total;   
  }
  
  return weight;
}




void draw(){
  stroke(0,0,100);
  background(0,0, 90);
 
  if(moreData == 0){          //Draw the data according to the mode
    image(notesImg,0,0);
  }
  else{
    image(notesImg,0,-50);
    image(framesImg,0,50);
  }
  
  stroke(55, 50,50);    //Draw the UI
  line(frameIdx/harmonizedNotes.length * width, 0, frameIdx/harmonizedNotes.length * width, 340);
  stroke(55, 50,70);
  for(int i = 0; i < 6; i++){
    if(currentInstrument == i) fill(55,50,80);
    else fill(55,50,50);    
    rect(i*100, height-30, 100,30); 
  }
  
  for(int i = 0; i < 6; i++){
    if(currentSource == i) fill(44,50,80);
    else fill(44,50,50);
    rect(i*100, height-60, 100,30); 
  }
  
  fill(55,20,50);
  rect(500, height-30, 100,30);
  
  
  textSize(14);  
  textAlign(CENTER); 
  fill(100);
  for(int i = 0; i < 6; i++){
    text(sourceNames[i], i*100+50, height-40); 
  }
  
  for(int i = 0; i < 5; i++){
    text(instrumentNames[i], i*100+50, height-10);
  }  
  
  text("More Data", 550, height-10);
  
  
  if(moreData == 1){          //Draw and create labels according to the mode
    fill(55,20,50);
    rect(0, height-90, 600,30);
    fill(55,20,70);
    rect(500, height-90, 100,30);
    fill(100);
    textAlign(LEFT);
    text("Source Root: " + noteNames[sourceRoot%12], 10, height-70);    
    text("Snap Notes to:  ", 390, height-70);
    textAlign(CENTER);
    text(snapNames[snapMode], 550, height-70);

  }
  
  
  
  
  
    
  frameIdx += sample.sampleRate()/fftSize/frameRate; //Control the playback position
  
  
  if (frameIdx > harmonizedNotes.length) frameIdx = 0;

  for(int i = 48; i < 120; i++){
    if(harmonizedNotes[(int)frameIdx][i] <= 0 && harmonizedNotes[((int)frameIdx+1)%harmonizedNotes.length][i] > 0){
            
      pitch.setConstant(getFrequency(i)/getFrequency(instrumentPitch));      //play the notes using the selected instrument
      instrument.trigger();
      
    }

  }
  
  

}

void keyPressed(){   
  saveFrame(); 
}


void mousePressed(){         
  if(mouseButton == LEFT){      //control the output and display of the sketch by choosing an instrument and a source
    
    if((height - mouseY)/30 == 0 && mouseX/100 < 5){
      int sample = mouseX/100; 
      
      getSampleData(instrumentPaths[sample]);        
      instrumentPitch = getRoot(notes);
      
      currentInstrument = sample;
      
      instrument = new Sampler( instrumentPaths[sample], 24, minim );
      
      pitch.patch(instrument.rate);  
      amp.patch(instrument.amplitude);  
      instrument.patch(out);

    }
    
    
    if((height - mouseY)/30 == 1){
      int sample = mouseX/100;
      
      getSampleData(sourcePaths[sample]);      
      sourceRoot = getRoot(notes);
      originalNotes = new float[notes.length][120];
      arrayCopy(notes, originalNotes);
      
      harmonizedNotes = harmonize(originalNotes, sourceRoot, snapMode);
      drawNotes();
      drawFrames();
      frameIdx = 0;
      
      currentSource = sample;
    
    }
    
    if((height - mouseY)/30 == 0 && mouseX/100 == 5){

      moreData = 1 - moreData;
      drawNotes();
      

    }
    
    if((height - mouseY)/30 == 2 && mouseX/100 == 5){

      snapMode = (snapMode+1)%3;
      
      
      harmonizedNotes = harmonize(originalNotes, sourceRoot, snapMode);      
      drawNotes();

    }
    
    
    
    
  }
  
  
}
