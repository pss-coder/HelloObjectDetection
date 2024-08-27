Goal: Detect an object live on camera feed and get live text output of what it is
- I need a camera feed
- I need a ml model that is trained in detecting objects from an image 
- I need to be able to predict from the camera and feed and input it to the ml (Vision Framework)


What we need: 
- Camera Manger: Handles camera work
- Vision Manager: Handles pipeline from ML to camera

Success: 
- Able to stream live camera feed into app
- Able to connect CoreML model to Vision Framework to perform object detection
- Able to add overlay border box around detected object using Vision Framework
- Able to connect to SwiftUI and display border via  SwiftUI Overlay

Work to be done: 
- Incorporate ARKit
    - To also measure length of detected item
- Semantic Segmentation
    - How can we add custom overlay according to the specific bounds of the object?
        - e.g: bound border to same shape as a banana 

Ways we can measure length of object
1. From Vision bound box: approximate length from 2 opposing points
    - We just need to know distance of object from phone to better approx height
2. Using ARKit, we can also take measurement between 2 points
