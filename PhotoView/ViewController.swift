//
//  ViewController.swift
//  PhotoView
//
//  Created by Macintosh on 4/6/16.
//  Copyright © 2016 Appinspire. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Photos

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MKMapViewDelegate{

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var mapView: MKMapView!
    
    var annotation: MKAnnotation!
    
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        imagePicker.delegate = self
        mapView.delegate = self
//        let longPress = UILongPressGestureRecognizer(target: self, action: "mapAction:")
//        longPress.minimumPressDuration = 1.0
//        self.mapView.addGestureRecognizer(longPress)
        
    }
/*
    func mapAction(gestureRecognizer:UIGestureRecognizer) {
        let touchPoint = gestureRecognizer.locationInView(self.mapView)
        var newCoord:CLLocationCoordinate2D = mapView.convertPoint(touchPoint, toCoordinateFromView: self.mapView)
        print("Gesture recognized")
   
        
        /*        */
    }

*/

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loadImageButtonTapped(sender: AnyObject) {
            imagePicker.allowsEditing = false
            imagePicker.sourceType = .PhotoLibrary
            
            presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
       
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageView.contentMode = .ScaleAspectFit
            imageView.image = pickedImage

           //For showing on the map
            let url: NSURL = info[UIImagePickerControllerReferenceURL] as! NSURL
            let phAssetResults = PHAsset.fetchAssetsWithALAssetURLs([url], options:nil)
            let asset = phAssetResults.firstObject
            let latitude = asset!.location!!.coordinate.latitude
            let longitude = asset!.location!!.coordinate.longitude
 
            let theSpan:MKCoordinateSpan = MKCoordinateSpanMake(0.1 , 0.1)
            let location = CLLocationCoordinate2DMake(latitude, longitude)
            let theRegion:MKCoordinateRegion = MKCoordinateRegionMake(location, theSpan)
            self.mapView.setRegion(theRegion, animated: true)
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = location
            annotation.title = "My Favorite Place"
            //annotation.subtitle = "Home of App Inspire"
            self.mapView.addAnnotation(annotation)
            
            
            print("\(latitude), \(longitude)")
            
            
            /*
            let library = ALAssetsLibrary()
            library.assetForURL(url, resultBlock: { (asset: ALAsset!) in
                if asset.valueForProperty(ALAssetPropertyLocation) != nil {
                    let latitude = (asset.valueForProperty(ALAssetPropertyLocation) as! CLLocation!).coordinate.latitude
                    let longitude = (asset.valueForProperty(ALAssetPropertyLocation) as! CLLocation!).coordinate.longitude
                    print("\(latitude), \(longitude)")
                    

                    
                    let theSpan:MKCoordinateSpan = MKCoordinateSpanMake(0.1 , 0.1)
                    let location = CLLocationCoordinate2DMake(latitude, longitude)
                    let theRegion:MKCoordinateRegion = MKCoordinateRegionMake(location, theSpan)
                    self.mapView.setRegion(theRegion, animated: true)

                    var annotation = MKPointAnnotation()
                    annotation.coordinate = location
                    annotation.title = "My Favorite Place"
                    //annotation.subtitle = "Home of App Inspire"
                    self.mapView.addAnnotation(annotation)
                }
                },
                failureBlock: { (error: NSError!) in
                    print(error.localizedDescription)
            })
            */
        }


  
        
        dismissViewControllerAnimated(true, completion: nil)
    }
    

    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        print("removing annotation")
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
        let btn2 = UIButton(type: .DetailDisclosure)
        annotationView.leftCalloutAccessoryView = btn2
        return annotationView
    }

    
}

