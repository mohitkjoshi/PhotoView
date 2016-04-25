//
//  ViewController.swift
//  PhotoView
//
//  Created by Macintosh on 4/6/16.
//  Copyright © 2016 Appinspire. All rights reserved.
//

import UIKit
import MapKit
import Photos


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MKMapViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    
    @IBOutlet weak var collectionCell: UICollectionViewCell!

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var imageCollectionView: UICollectionView!


    let imagePicker = UIImagePickerController()
    let configuration = NSURLSessionConfiguration .defaultSessionConfiguration()
    let S3BucketName = "publicphotoswithlocation"
    let S3BucketURL = "https://s3.amazonaws.com/publicphotoswithlocation/public/"
    var photoCollection = [PhotoInfo]()
    var previousPhotoIndex:Int = 0
    
    var hasMapRegionChanged = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("size of collection at viewDidLoad \(photoCollection.count)")
    
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
 //       if let , , zoomedPhotoViewController = segue.destinationViewController as? ZoomViewController {
        
            print("prepare for segue \(self.photoCollection.count)")
            let zoomedPhotoViewController = segue.destinationViewController as? ZoomViewController
            let cell = sender as? UICollectionViewCell
            if(cell == nil){
                print("cell is nil")
            }
            let indexPath = imageCollectionView?.indexPathForCell(cell!)
            print(indexPath)
            zoomedPhotoViewController!.photoCollection = self.photoCollection
            zoomedPhotoViewController!.photoIndex = indexPath!.item
 //       }
    }
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loadImageButtonTapped(sender: AnyObject) {
//            imagePicker.sourceType = .PhotoLibrary
//            presentViewController(imagePicker, animated: true, completion: nil)
    }

    
   
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
       

            let pickedImage =  info[UIImagePickerControllerOriginalImage] as? UIImage

           //For showing on the map, get the location
            let url: NSURL = info[UIImagePickerControllerReferenceURL] as! NSURL
            let phAssetResults = PHAsset.fetchAssetsWithALAssetURLs([url], options:nil)
            let asset = phAssetResults.firstObject
            let latitude = asset?.location??.coordinate.latitude
            let longitude = asset?.location??.coordinate.longitude
            let imageName = url.lastPathComponent
            print(imageName)
            var lat = String((latitude! as Double))
            var long = String((longitude! as Double))
        
        
        //store location in mysql and get a photoid
        //make a POST call to a REST service on AWS. The service will save it in an indexed mysql table to make query faster.
        //http: //ec2-54-84-51-72.compute-1.amazonaws.com:8888/location/?latitude=38.0374445&longitude=-122.803178333333
        let session = NSURLSession(configuration: configuration)
        let urlString = NSString(format: "http://ec2-54-84-51-72.compute-1.amazonaws.com:8888/location/?latitude=\(lat)&longitude=\(long)")
        
        
        print("post url string is \(urlString)")
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.URL = NSURL(string: NSString(format: "%@", urlString) as String)
        request.HTTPMethod = "GET"
        request.timeoutInterval = 30
 
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        var photoId:String?
        
        let dataTask = session.dataTaskWithRequest(request) {
            (let data: NSData?, let response: NSURLResponse?, let error: NSError?) -> Void in
            
            // 1: Check HTTP Response for successful POST request
            guard let httpResponse = response as? NSHTTPURLResponse, receivedData = data
                else {
                    print("error: not a valid http response \(response)")
                    return
            }
            
            switch (httpResponse.statusCode)
            {
            case 200:
                
                let response = NSString (data: receivedData, encoding: NSUTF8StringEncoding)
                print("response is \(response)")
                
                
                do {
                    let getResponse = try NSJSONSerialization.JSONObjectWithData(receivedData, options: .AllowFragments)
                    photoId = (getResponse["id"] as? String)!
                    print(photoId)
                
                    // }
                } catch {
                    print("error serializing JSON: \(error)")
                }
                
                break
            case 400:
                
                break
            default:
                print("POST request got response \(httpResponse.statusCode)")
            }
            
            //upload on AWS
            let transferManager = AWSS3TransferManager.defaultS3TransferManager()
            
            
            let documentDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first! as String
            print(documentDirectory)
            // getting local path
            let localPath = (documentDirectory as NSString).stringByAppendingPathComponent(imageName!)
            print(localPath)
            let imageURL = NSURL(fileURLWithPath: localPath)
            let uploadRequest1 : AWSS3TransferManagerUploadRequest = AWSS3TransferManagerUploadRequest()
            
            let data = UIImageJPEGRepresentation(pickedImage!, 0.05)
            data!.writeToFile(localPath, atomically: true)
            uploadRequest1.bucket = "publicphotoswithlocation"
            uploadRequest1.key =  "public/" + photoId!
            uploadRequest1.body = imageURL
            
            let task = transferManager.upload(uploadRequest1)
            
            task.continueWithBlock { (task: AWSTask!) -> AnyObject! in
                if task.error != nil {
                    print("Error: \(task.error)")
                } else {
                    print("Upload successful")
                }
                return nil
            }

        }
        dataTask.resume()
       
      //test AWS UnAuth id not allowed to list tables
        /*let dynamoDB = AWSDynamoDB.defaultDynamoDB()
        let listTableInput = AWSDynamoDBListTablesInput()
            dynamoDB.listTables(listTableInput).continueWithBlock{ (task: AWSTask!) -> AnyObject? in
            if let error = task.error {
                print("Error occurred: \(error)")
                return nil
            }
            
            let listTablesOutput = task.result as! AWSDynamoDBListTablesOutput
            
            for tableName : AnyObject in listTablesOutput.tableNames! {
                print("\(tableName)")
            }
            
            return nil
        }
        */
        

        //dismiss image picker
        dismissViewControllerAnimated(true, completion: nil)
    }
    

    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {

        if let annotation = view.annotation as? MKPointAnnotation {
            let latitude = annotation.coordinate.latitude
            let longitude = annotation.coordinate.longitude
            let targetURL = NSURL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)&saddr=Edison")!
            if (UIApplication.sharedApplication().canOpenURL(targetURL)) {
                UIApplication.sharedApplication().openURL(targetURL)
            } else {
                print("Apple map routing is not avilable")
            }
        }
    }
    
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
       
//        let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "myPin")
        var bundlePath:String?
        if annotation.isKindOfClass(LeafAnnotation)
        {
            bundlePath = NSBundle.mainBundle().pathForResource((annotation as? LeafAnnotation)?.imageName, ofType: "gif")
        } else if annotation.isKindOfClass(SelectedAnnotation) {
            bundlePath = NSBundle.mainBundle().pathForResource((annotation as? SelectedAnnotation)?.imageName, ofType: "gif")
       
        }
            
        var img = UIImage(contentsOfFile: bundlePath!)
        
        
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "myPin")

        annotationView.canShowCallout = true
        let btn = UIButton(type: .DetailDisclosure)
        annotationView.leftCalloutAccessoryView = btn

        annotationView.image = img
        annotationView.frame = CGRect(x: 0, y: 0, width: 12, height: 12)
        return annotationView
    }
 
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let myRegion = mapView.region
        print ("latitude \(myRegion.center.latitude) longitude \(myRegion.center.longitude) delta \(myRegion.span.latitudeDelta)")
        let south = myRegion.center.latitude - myRegion.span.latitudeDelta / 2.0
        let north = myRegion.center.latitude + myRegion.span.latitudeDelta / 2.0
        let west = myRegion.center.longitude - myRegion.span.longitudeDelta / 2.0
        let east = myRegion.center.longitude + myRegion.span.longitudeDelta / 2.0
        print("calling resetview \(south), \(north), \(west), \(east)")
        resetView( south, lat2: north, long1: west, long2: east)
    }
    
    override func viewWillAppear(animated: Bool) {
        imagePicker.delegate = self
        mapView.delegate = self
        imageCollectionView.delegate = self
        imageCollectionView.dataSource = self
        
        let currLat = 40.5
        let currLong = -75.0
        let currLocation = CLLocationCoordinate2DMake(currLat, currLong)
        //        let initLatDelta = 5.0
        //        let initLongDelta = 6.0
        let initLatDelta = 2.5
        let initLongDelta = 3.0
        //        imageCollectionView.registerClass(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        //        print("registered ViewCell class with collectionView")
        imageCollectionView.backgroundColor = UIColor.orangeColor()
        
        /*        var doubleTapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "didDoubleTapCollectionView:")
        doubleTapGesture.numberOfTapsRequired = 2  // add double tap
        doubleTapGesture.delaysTouchesBegan = true
        self.imageCollectionView.addGestureRecognizer(doubleTapGesture)
        */
        //get photos from AWS and show on the map
        
        let lat1 = currLat - initLatDelta/2 //south
        let lat2 = currLat + initLatDelta/2 //north
        
        let long1 = currLong - initLongDelta/2  //west
        let long2 = currLong + initLongDelta/2  //east
        
        let theSpan:MKCoordinateSpan = MKCoordinateSpanMake(4 , 4)
        //map will be show the region around our location
        let loc = CLLocationCoordinate2DMake(currLat, currLong)
        let theRegion:MKCoordinateRegion = MKCoordinateRegionMake(loc, theSpan)
        self.mapView.setRegion(theRegion, animated: true)
        resetView(lat1, lat2: lat2, long1: long1, long2: long2)
        
        hasMapRegionChanged = true
       
    }
    
    func resetView(lat1:Double, lat2:Double, long1:Double, long2:Double) {
        
        //a new query will fetch new images. If the images already exist, do not overwrite them. For now, overwriting them
        photoCollection = [PhotoInfo]()
        previousPhotoIndex = 0
        //zoomedPhotoViewController.photoCollection = photoCollection

        //get all photos posted within a the map rectangle
        if(hasMapRegionChanged){
            let session = NSURLSession(configuration: configuration)
            let urlString = NSString(format: "http://ec2-54-84-51-72.compute-1.amazonaws.com:8888/IDlist/?lat1=\(lat1)&lat2=\(lat2)&long1=\(long1)&long2=\(long2)")
            
            
            print("get url string is \(urlString)")
            let request : NSMutableURLRequest = NSMutableURLRequest()
            request.URL = NSURL(string: NSString(format: "%@", urlString) as String)
            request.HTTPMethod = "GET"
            request.timeoutInterval = 30
            
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            
            let dataTask = session.dataTaskWithRequest(request) {
                (let data: NSData?, let response: NSURLResponse?, let error: NSError?) -> Void in
                
                // 1: Check HTTP Response for successful POST request
                guard let httpResponse = response as? NSHTTPURLResponse, receivedData = data
                    else {
                        print("error: not a valid http response for list of photos \(response)")
                        return
                }
                
                switch (httpResponse.statusCode)
                {
                case 200:
                    
                    let response = NSString (data: receivedData, encoding: NSUTF8StringEncoding)
                    print("response is \(response)")
                    
                    
                    do {
                        let getResponse = try NSJSONSerialization.JSONObjectWithData(receivedData, options: .AllowFragments)
                        
                        let list  = getResponse["list"]
                        for listitem in (list as? NSArray)!{
                            let photoId = String(listitem["id"])
                            let latitude = Double(String(listitem["lat"]))
                            let longitude = Double(String(listitem["long"]))
                            print(String(photoId) + String(latitude) )
                            
                            let annotation = LeafAnnotation()
                            
                            //autolayout engine must be modified in the main thread
                            NSOperationQueue.mainQueue().addOperationWithBlock {
                                //create a pin and show on the map
                                //get the location
                                if (latitude != nil && longitude != nil) {
                                    let location = CLLocationCoordinate2DMake(latitude!, longitude!)
                                    //create a dropped pin
                                    annotation.coordinate = location
                                    annotation.title = "My Favorite Place"
                                    self.mapView.addAnnotation(annotation)
                                    print("added annotation to map")
                                } else {
                                    print("photo do not have geotagging")
                                }
                            }//end autolayout main queue block
                            //display the images from AWS
                            
                            let imgURL = NSURL(string: self.S3BucketURL + photoId)
                            let request: NSURLRequest = NSURLRequest(URL: imgURL!)
                            let config = NSURLSessionConfiguration.defaultSessionConfiguration()
                            let session = NSURLSession(configuration: config)
                            
                            
                            
                            let task = session.dataTaskWithRequest(request, completionHandler: {(data, response, error) in
                                
                                if error == nil {
                                    print("got some data back" + (response?.description)!)
                                    
                                    //autolayout engine must be modified in the main thread
                                    NSOperationQueue.mainQueue().addOperationWithBlock {
                                        let img = UIImage(data: data!)
                                        self.photoCollection.append(PhotoInfo(img: img!, lat: latitude!, long: longitude!, id: photoId, annotation:annotation ))
                                        
                                        //**** if this is the last photo, reload data in collection view, and set the region on map to show annotations
                                        
                                        if(self.photoCollection.count == (list as? NSArray)!.count) {
                                            self.imageCollectionView.reloadData()
                                            self.hasMapRegionChanged = true
                                        }
                                    }
                                } else {
                                    print("error showing s3 image: \(error)")
                                }
                                
                            });
                            
                            task.resume()
                        }

                    } catch {
                        print("error serializing JSON: \(error)")
                    }
                    
                    break
                case 400:
                    
                    break
                default:
                    print("POST request got response \(httpResponse.statusCode)")
                }
                
                
            }
            dataTask.resume()
            hasMapRegionChanged = false
        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        // get a reference to our storyboard cell
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! PhotoCell
         print("Created a new Cell \(indexPath.item)")
        // Use the outlet in our custom class to get a reference to the UILabel in the cell
        let img = self.photoCollection[indexPath.item].image
        let imgView = UIImageView(image: img)
        imgView.contentMode = .ScaleAspectFill
        imgView.clipsToBounds = true
        imgView.frame = CGRectMake(0, 0, 92, 92);
        cell.backgroundColor = UIColor.grayColor() // make cell more visible in our example project
        cell.addSubview(imgView)
 
        
//        imageCollectionView.reloadData()
//        cell.customImgView.image = img
        return cell
    }
    
    // MARK: - UICollectionViewDelegate protocol
 /*
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        // handle tap events

        print("You selected cell #\(indexPath.item)!")

    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        print("You Deselected cell #\(indexPath.item)!")
    }
*/
    // tell the collection view how many cells to make
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("size of photo collection \(self.photoCollection.count)")
        return self.photoCollection.count
    }
    
    //for highlighted photos
    func collectionView(collectionView: UICollectionView, didHighlightItemAtIndexPath indexPath: NSIndexPath) {
        print("You highlighted cell #\(indexPath.item)!")
        highlghtAnnotation(indexPath.item)
    }
/*
    // make a cell for each cell index path
    func collectionView(collectionView: UICollectionView, didUnhighlightItemAtIndexPath indexPath: NSIndexPath) {
        print("You Un highlighted cell #\(indexPath.item)!")
    }
  */
    
    
    /*
    func didDoubleTapCollectionView(gesture: UITapGestureRecognizer) {
        var pointInCollectionView: CGPoint = gesture.locationInView(self.imageCollectionView)
        var selectedIndexPath: NSIndexPath = self.imageCollectionView.indexPathForItemAtPoint(pointInCollectionView)!
        print("selected by double tap \(selectedIndexPath.item)")
        var selectedCell = self.imageCollectionView.cellForItemAtIndexPath(selectedIndexPath)
        
        // Rest code
    }
*/
    
    func highlghtAnnotation(index:Int){
        if(previousPhotoIndex != -1){
            let photoInfo = self.photoCollection[previousPhotoIndex] as? PhotoInfo
            let selectedAnnotation = photoInfo!.annotation!
            
            let regularAnnotation = LeafAnnotation()
            regularAnnotation.coordinate = selectedAnnotation.coordinate
            regularAnnotation.title = "fall color photo"
            photoInfo?.annotation = regularAnnotation
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.mapView.removeAnnotation(selectedAnnotation)
                self.mapView.addAnnotation(regularAnnotation)
                print("un highlighted annotation for image \(self.previousPhotoIndex)")
            }
        }
        
        //change color of annotation
        //remove existing annotation and add a new one
        let photoInfo = self.photoCollection[index]
        let regularAnnotation = photoInfo.annotation
        
        let selectedAnnotation = SelectedAnnotation()
        selectedAnnotation.coordinate = (regularAnnotation?.coordinate)!
        selectedAnnotation.title = "location of highlighted photo"
        photoInfo.annotation = selectedAnnotation
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.mapView.removeAnnotation(regularAnnotation!)
            self.mapView.addAnnotation(selectedAnnotation)
            print("highlighted annotation for image \(index)")
            
        }
        previousPhotoIndex = index
    
    }
    
}


