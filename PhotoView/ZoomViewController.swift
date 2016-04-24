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
    

    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
  
    
    var photoCollection = [PhotoInfo]()
    var photoIndex:Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        zoomImgView.image  = (photoCollection[photoIndex] as? PhotoInfo)?.image

        scrollView.delegate = self

        
    }
    
}


extension ZoomViewController: UIScrollViewDelegate {
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return zoomImgView
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
         updateMinZoomScaleForSize(view.bounds.size)
    }

    private func updateMinZoomScaleForSize(size: CGSize) {
        let widthScale = size.width / zoomImgView.bounds.width
        let heightScale = size.height / zoomImgView.bounds.height
        let minScale = min(widthScale, heightScale)
        
        scrollView.minimumZoomScale = minScale
        
        scrollView.zoomScale = minScale
    }

}


