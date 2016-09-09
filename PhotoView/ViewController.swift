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

var photoCollection = [PhotoInfo]()
var previousPhotoIndex:Int = -1
//let S3BucketName = "publicphotoswithlocation"
let S3BucketURL = "https://s3.amazonaws.com/publicphotoswithlocation/public/"

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MKMapViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource {

    @IBOutlet weak var collectionCell: UICollectionViewCell!

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var imageCollectionView: UICollectionView!


    let imagePicker = UIImagePickerController()
    let configuration = NSURLSessionConfiguration .defaultSessionConfiguration()



    
    var hasMapRegionChanged = true
    var initialViewLoadComplete = false
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.Portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("size of collection at viewDidLoad \(photoCollection.count)")
    
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
 //       if let , , zoomedPhotoViewController = segue.destinationViewController as? ZoomViewController {
        
            print("prepare for segue \(photoCollection.count)")
            let zoomedPhotoViewController = segue.destinationViewController as? ZoomViewController
            let cell = sender as? UICollectionViewCell
            if(cell == nil){
                print("cell is nil")
            }
            let indexPath = imageCollectionView?.indexPathForCell(cell!)
            print(indexPath)
 //         zoomedPhotoViewController!.photoCollection = photoCollection
            zoomedPhotoViewController!.photoIndex = indexPath!.item
 //       }
            //reset should be called only during initial page load, but not when use returns from segue
            print("value of RegionChanged at segue \(hasMapRegionChanged)")
            hasMapRegionChanged = false
    }
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return .None
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loadImageButtonTapped(sender: AnyObject) {
            imagePicker.sourceType = .PhotoLibrary
	            presentViewController(imagePicker, animated: true, completion: nil)
    }

    
   
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
       

            let pickedImage =  info[UIImagePickerControllerOriginalImage] as? UIImage

           //For showing on the map, get the location
            let url: NSURL = info[UIImagePickerControllerReferenceURL] as! NSURL
            let phAssetResults = PHAsset.fetchAssetsWithALAssetURLs([url], options:nil)
            let asset = phAssetResults.firstObject
            let latitude = asset?.location??.coordinate.latitude
            let longitude = asset?.location??.coordinate.longitude
            if(latitude == nil){
                
                let alert = UIAlertView()
                alert.title = "photo location missing"
                alert.message = "Your photo could not be uploaded because it doesnt have location information"
                alert.addButtonWithTitle("Ok")
                alert.show()
                dismissViewControllerAnimated(true, completion: nil)
                return
            }
        
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
            let uploadRequest1 : AWSS3TransferManagerUploadRequest = AWSS3TransferManagerUploadRequest()
            var data = UIImageJPEGRepresentation(pickedImage!, 0.25)
            data!.writeToFile(localPath, atomically: true)

            let imageURL = NSURL(fileURLWithPath: localPath)
            uploadRequest1.bucket = "publicphotoswithlocation"
            uploadRequest1.key =  "public/" + photoId!
            uploadRequest1.body = imageURL
            uploadRequest1.ACL = AWSS3ObjectCannedACL.PublicRead
            let task = transferManager.upload(uploadRequest1)

            task.continueWithBlock { (task: AWSTask!) -> AnyObject! in
                if task.error != nil {
                    print("Error: \(task.error)")
                } else {
                    print("Upload successful")
                }
                return nil
            }

//upload a thumbnail as well, maintaining the aspect ratio with target size of 184 by 184 pixels, since we are showing in 92 by 92 points, so this works well on iphone 6 plus as well
//            let scl = UIScreen.mainScreen().scale
            //print("scl \(scl)")
            let scale = pickedImage!.size.height<pickedImage!.size.width ? 276/pickedImage!.size.height : 276/pickedImage!.size.width
            let newSize = CGSize(width: pickedImage!.size.width * scale, height: pickedImage!.size.height * scale)
            print("scale \(scale)")
       
            UIGraphicsBeginImageContext(newSize)
            pickedImage!.drawInRect(CGRectMake(0, 0, pickedImage!.size.width * scale, pickedImage!.size.height * scale))
            let thumbnailImg = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
       
            

            let thumbLocalPath = (documentDirectory as NSString).stringByAppendingPathComponent("thumbnail_" + imageName!)
            let thumbImgURL = NSURL(fileURLWithPath: thumbLocalPath)
//            let data2 = UIImageJPEGRepresentation(pickedImage!, scale * scale)
            let data2 = UIImageJPEGRepresentation(thumbnailImg, 0.5)
            data2!.writeToFile(thumbLocalPath, atomically: true)
            
            let uploadRequest2 : AWSS3TransferManagerUploadRequest = AWSS3TransferManagerUploadRequest()
            uploadRequest2.bucket = "publicphotoswithlocation"
            uploadRequest2.key = "public/thumbnail_" + photoId!
            uploadRequest2.body = thumbImgURL
            uploadRequest2.ACL = AWSS3ObjectCannedACL.PublicRead
            let task1 = transferManager.upload(uploadRequest2)
            task1.continueWithBlock { (task: AWSTask!) -> AnyObject! in
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
        let alert = UIAlertView()
        alert.title = "photo uploaded"
        alert.message = "Your photo has been uploaded."
        alert.addButtonWithTitle("Ok")
        alert.show()
        dismissViewControllerAnimated(true, completion: nil)
        return

        //dismiss image picker
        dismissViewControllerAnimated(true, completion: nil)
    }
    

    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {

        if let annotation = view.annotation as? MKPointAnnotation {
            let latitude = annotation.coordinate.latitude
            let longitude = annotation.coordinate.longitude
            let targetURL = NSURL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)")!
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
        } else if annotation.isKindOfClass(OldAnnotation){
            bundlePath = NSBundle.mainBundle().pathForResource((annotation as? OldAnnotation)?.imageName, ofType: "gif")
        }
            
        var img = UIImage(contentsOfFile: bundlePath!)
        
        
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "myPin")
        annotationView.canShowCallout = true

        
        // 5
        var bundlePathDir = NSBundle.mainBundle().pathForResource("directions", ofType: "png")
        var imgDir = UIImage(contentsOfFile: bundlePathDir!)
        //             let img = UIImage(contentsOfFile: "")
/*        let imageView = UIImageView(image: imgDir)
        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:Selector("imageTapped:"))
        
        imageView.userInteractionEnabled = true
        imageView.addGestureRecognizer(tapGestureRecognizer)
        
        imageView.frame = CGRect(x: 0, y: 0, width: 25, height: 25)
        annotationView.leftCalloutAccessoryView = imageView
        
*/

//        let btn = UIButton(type: .DetailDisclosure)
        let btn = UIButton(type: .Custom)
        btn.frame = CGRect(x: 0, y: 0, width: 25, height: 25)
 //       if let imageDirections = UIImage(named: "directions.png") {
            
            btn.setImage(imgDir, forState: .Normal)
 //       }
        annotationView.leftCalloutAccessoryView = btn

        annotationView.image = img

        if (annotation.isKindOfClass(LeafAnnotation) || annotation.isKindOfClass(OldAnnotation))
        {
            annotationView.layer.zPosition = -1
            annotationView.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        } else if annotation.isKindOfClass(SelectedAnnotation) {
            annotationView.layer.zPosition = 0
            annotationView.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
            
        }
        

        return annotationView
    }
 
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if(initialViewLoadComplete) {
            let myRegion = mapView.region
            print ("latitude \(myRegion.center.latitude) longitude \(myRegion.center.longitude) delta \(myRegion.span.latitudeDelta)")
            let south = myRegion.center.latitude - myRegion.span.latitudeDelta / 2.0
            let north = myRegion.center.latitude + myRegion.span.latitudeDelta / 2.0
            let west = myRegion.center.longitude - myRegion.span.longitudeDelta / 2.0
            let east = myRegion.center.longitude + myRegion.span.longitudeDelta / 2.0
            print("calling resetview \(south), \(north), \(west), \(east)")
            hasMapRegionChanged = true
            resetView( south, lat2: north, long1: west, long2: east)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        imagePicker.delegate = self
        mapView.delegate = self
        imageCollectionView.delegate = self
        imageCollectionView.dataSource = self
        
        if(!initialViewLoadComplete) {
            let currLat = 44.5
            let currLong = -76.5
            let currLocation = CLLocationCoordinate2DMake(currLat, currLong)
            //        let initLatDelta = 5.0
            //        let initLongDelta = 6.0
            let initLatDelta = 7.5
            let initLongDelta = 9.0
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
            
            let theSpan:MKCoordinateSpan = MKCoordinateSpanMake(8 , 8)
            //map will be show the region around our location
            let loc = CLLocationCoordinate2DMake(currLat, currLong)
            let theRegion:MKCoordinateRegion = MKCoordinateRegionMake(loc, theSpan)
            self.mapView.setRegion(theRegion, animated: true)
            
            //reset should be called only during initial page load, but not when use returns from segue


            print("View will appear resetView call")
            resetView(lat1, lat2: lat2, long1: long1, long2: long2)
        }
        
    }
    
    func resetView(lat1:Double, lat2:Double, long1:Double, long2:Double) {
        
        //a new query will fetch new images. If the images already exist, do not overwrite them. For now, overwriting them
        

        //zoomedPhotoViewController.photoCollection = photoCollection

        //get all photos posted within a the map rectangle
        if(hasMapRegionChanged){
            //before we set photoCollection to a new Array, we need to remove the annotations which were already added to the MapView
            let allAnnotations = self.mapView.annotations
            self.mapView.removeAnnotations(allAnnotations)
            //
            photoCollection = [PhotoInfo]()
            previousPhotoIndex = -1

            
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
                        var listSize = (list as? NSArray)!.count
                        for listitem in (list as? NSArray)!{
                            
                            let photoId = String(listitem["id"])
                            let latitude = Double(String(listitem["lat"]))
                            let longitude = Double(String(listitem["long"]))
                            let dt = String(listitem["date"])
                            print(String(photoId) + String(latitude) )
                            
                            let date = NSDate()
                            let priorDay = date.dateByAddingTimeInterval(NSTimeInterval(-172800))
                            
                            let photoDate = NSDate(dateString:dt)
                            var annotation:MKPointAnnotation
                            if (photoDate.compare(priorDay) == NSComparisonResult.OrderedDescending){
                                annotation = LeafAnnotation()
                            } else {
                                annotation = OldAnnotation()
                            }
                            
                            
                            
                            
                            //autolayout engine must be modified in the main thread
                            NSOperationQueue.mainQueue().addOperationWithBlock {
                                //create a pin and show on the map
                                //get the location
                                if (latitude != nil && longitude != nil) {
                                    let location = CLLocationCoordinate2DMake(latitude!, longitude!)
                                    //create a dropped pin
                                    annotation.coordinate = location
                                    annotation.title = dt
                                    self.mapView.addAnnotation(annotation)
                                    print("added annotation to map")
                                } else {
                                    print("photo do not have geotagging")
                                }
                            }//end autolayout main queue block
                            //display the images from AWS
                            
                            let imgURL = NSURL(string: S3BucketURL + "thumbnail_" + photoId)
                            let request: NSURLRequest = NSURLRequest(URL: imgURL!)
                            let config = NSURLSessionConfiguration.defaultSessionConfiguration()
                            let session = NSURLSession(configuration: config)
                            
                            
                            
                            let task = session.dataTaskWithRequest(request, completionHandler: {(data, response, error) in
                                
                                if error == nil {
                                    print("got some data back" + (response?.description)!)
                                    
                                    //autolayout engine must be modified in the main thread
                                    NSOperationQueue.mainQueue().addOperationWithBlock {
                                        let img = UIImage(data: data!)
                                        if (img == nil){
                                            print("Thumbnail not found")
                                            listSize = listSize - 1
                                            
                                        } else {
                                        
                                            photoCollection.append(PhotoInfo(img: img!, lat: latitude!, long: longitude!, id: photoId, date:dt, annotation:annotation ))
                                        }
                                        //**** if this is the last photo, reload data in collection view, and set the region on map to show annotations
                                        
                                        if(photoCollection.count == listSize) {
                                            self.imageCollectionView.reloadData()
                                            //LoadInitialView and MapResize get fired simultaneously. Wait till last image load to avoid multiple loads in parallel.
                                            self.initialViewLoadComplete = true
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
            //set the flag when worker thread completes, not in the main thread
            print("regionChanged False in worker tread")
            hasMapRegionChanged = false
        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        // get a reference to our storyboard cell
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! PhotoCell
         print("Created a new Cell \(indexPath.item)")
        // Use the outlet in our custom class to get a reference to the UILabel in the cell
        let img = photoCollection[indexPath.item].image
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
        print("size of photo collection \(photoCollection.count)")
        return photoCollection.count
    }
    
    //for highlighted photos
    func collectionView(collectionView: UICollectionView, didHighlightItemAtIndexPath indexPath: NSIndexPath) {
        print("You highlighted cell #\(indexPath.item)!")
        highlghtAnnotation(indexPath.item)
        if(previousPhotoIndex != -1){
        //    let cell = collectionView.cellForItemAtIndexPath(NSIndexPath(index: previousPhotoIndex))
        }
        
        //let cell = collectionView.cellForItemAtIndexPath(indexPath)
        //cell!.layer.borderWidth = 1.0
        //cell!.layer.borderColor = UIColor.yellowColor().CGColor
    
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
        print("previous index \(previousPhotoIndex) new Index \(index)")
        if(previousPhotoIndex != -1){
            let photoInfo = photoCollection[previousPhotoIndex] as? PhotoInfo
            let selectedAnnotation = photoInfo!.annotation!
            var regularAnnotation:MKPointAnnotation
            if(photoInfo!.annotationType == "Leaf"){
                regularAnnotation = LeafAnnotation()
            }
            else {
                regularAnnotation = OldAnnotation()
            }
            regularAnnotation.coordinate = selectedAnnotation.coordinate
            regularAnnotation.title = selectedAnnotation.title
            photoInfo?.annotation = regularAnnotation
//            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.mapView.removeAnnotation(selectedAnnotation)
                self.mapView.addAnnotation(regularAnnotation)
                print("un highlighted annotation for image \(previousPhotoIndex)")
//            }
        }
        
        //change color of annotation
        //remove existing annotation and add a new one
        let photoInfo = photoCollection[index]
        let regularAnnotation = photoInfo.annotation
        
        let selectedAnnotation = SelectedAnnotation()
        selectedAnnotation.coordinate = (regularAnnotation?.coordinate)!
        selectedAnnotation.title = (regularAnnotation?.title)!
        photoInfo.annotation = selectedAnnotation
//        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.mapView.removeAnnotation(regularAnnotation!)
            self.mapView.addAnnotation(selectedAnnotation)
            print("highlighted annotation for image \(index)")
            
//	        }
        previousPhotoIndex = index
    
    }
    
}

extension UINavigationController {
    public override func shouldAutorotate() -> Bool {
        return false
    }

}

extension NSDate
{
    convenience
    init(dateString:String) {
        let dateStringFormatter = NSDateFormatter()
        dateStringFormatter.dateFormat = "yyyy-MM-dd"
        dateStringFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        let d = dateStringFormatter.dateFromString(dateString)!
        self.init(timeInterval:0, sinceDate:d)
    }
}


