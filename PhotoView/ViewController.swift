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


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MKMapViewDelegate{

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var mapView: MKMapView!
    
   
    let imagePicker = UIImagePickerController()
    let configuration = NSURLSessionConfiguration .defaultSessionConfiguration()
    let S3BucketName = "publicphotoswithlocation"
    let S3BucketURL = "https://s3.amazonaws.com/publicphotoswithlocation/public/"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker.delegate = self
        mapView.delegate = self
        
        //get photos from AWS and show on the map
        let session = NSURLSession(configuration: configuration)
        let lat1 = 37
        let lat2 = 39
        let long1 = -123
        let long2 = -122
        //get all photos posted within a the map rectangle
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
                        let photoId = listitem["id"]
                        let latitude = Double(String(listitem["lat"]))
                        let longitude = Double(String(listitem["long"]))
                        print(String(photoId) + String(latitude) )

                        //autolayout engine must be modified in the main thread
                        NSOperationQueue.mainQueue().addOperationWithBlock {
                            //create a pin and show on the map
                            //default zoom for map
                            let theSpan:MKCoordinateSpan = MKCoordinateSpanMake(0.1 , 0.1)
                            //get the location
                            if (latitude != nil && longitude != nil) {
                                let location = CLLocationCoordinate2DMake(latitude!, longitude!)
                                //map will be show the region around our location
                                let theRegion:MKCoordinateRegion = MKCoordinateRegionMake(location, theSpan)
                                self.mapView.setRegion(theRegion, animated: true)
                                
                                //create a dropped pin
                                let annotation = MKPointAnnotation()
                                annotation.coordinate = location
                                annotation.title = "My Favorite Place"
                                self.mapView.addAnnotation(annotation)
                            } else {
                                print("photo do not have geotagging")
                            }
                        }//end autolayout main queue block
                        //display the images from AWS

                        let imgURL = NSURL(string: self.S3BucketURL + String(photoId))
                        let request: NSURLRequest = NSURLRequest(URL: imgURL!)
                        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
                        let session = NSURLSession(configuration: config)
                    

                        
                        let task = session.dataTaskWithRequest(request, completionHandler: {(data, response, error) in
                            
                            if error == nil {
                                print("got some data back" + (response?.description)!)
                                
                                //autolayout engine must be modified in the main thread
                                NSOperationQueue.mainQueue().addOperationWithBlock {

                                    self.imageView.image = UIImage(data: data!)
                                }
                            } else {
                                print("error showing s3 image: \(error)")
                            }
                            
                        });
                    
                    
                        task.resume()

                            

                        
                        //display both image and annotation
                    
                    }

                    
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
            
         
        }
        dataTask.resume()
     
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
       

            //imageView.image =  info[UIImagePickerControllerOriginalImage] as? UIImage

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
            
            let data = UIImageJPEGRepresentation(self.imageView.image!, 0.05)
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
       
        let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "myPin")
        annotationView.canShowCallout = true
        let btn = UIButton(type: .DetailDisclosure)
        annotationView.leftCalloutAccessoryView = btn
        return annotationView
    }

    
}

