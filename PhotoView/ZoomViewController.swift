//
//  ZoomViewController.swift
//  PhotoView
//
//  Created by Macintosh on 4/23/16.
//  Copyright © 2016 Appinspire. All rights reserved.
//

import UIKit

class ZoomViewController: UIViewController{

    @IBOutlet weak var zoomImgView: UIImageView!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    var photoInfo:PhotoInfo?
    


    @IBAction func directionsButtonPressed(sender: AnyObject) {
        //open photo location in maps
        let latitude = photoInfo!.latitude
        let longitude = photoInfo!.longitude
        let targetURL = NSURL(string: "http://maps.apple.com/?daddr=\(latitude),\(longitude)")!
        print(targetURL)
        if (UIApplication.sharedApplication().canOpenURL(targetURL)) {
            UIApplication.sharedApplication().openURL(targetURL)
        } else {
            print("Could not open url")
        }
    }

    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
  
    
//    var photoCollection = [PhotoInfo]()
    var photoIndex:Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.delegate = self
        photoInfo = photoCollection[photoIndex] as PhotoInfo
        let photoId = (photoCollection[photoIndex] as? PhotoInfo)?.ID
        let imgURL = NSURL(string: S3BucketURL + photoId!)
        print("Full Image URL :\(imgURL)")
        let request: NSURLRequest = NSURLRequest(URL: imgURL!)
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config)
        
        
        
        let task = session.dataTaskWithRequest(request, completionHandler: {(data, response, error) in
            
            if error == nil {
                print("got some data back" + (response?.description)!)
                
                //autolayout engine must be modified in the main thread
                NSOperationQueue.mainQueue().addOperationWithBlock {
                    let img = UIImage(data: data!)
                    self.zoomImgView.contentMode = .ScaleAspectFill	
                    self.zoomImgView.image  = img
                    print("image set \(img!.size)")
                    self.updateMinZoomScaleForSize(self.view.bounds.size)
                 
                }
            } else {
                print("error showing s3 image: \(error)")
            }
        });
        
        task.resume()
        
       

        
    }
    
}


extension ZoomViewController: UIScrollViewDelegate {
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return zoomImgView
    }
    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//
//    }

    private func updateMinZoomScaleForSize(size: CGSize) {
        if (zoomImgView.image != nil){
            print("width \(zoomImgView.image!.size.width) height \(zoomImgView.image!.size.height)")
            let widthScale = size.width / zoomImgView.image!.size.width
            let heightScale = size.height / zoomImgView.image!.size.height
            let minScale = min(widthScale, heightScale)
            
            scrollView.minimumZoomScale = minScale
            
            scrollView.zoomScale = minScale
            print("set min scale \(minScale.native)")
        }
    }

}


