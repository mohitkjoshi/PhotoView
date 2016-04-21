//
//  PopUpViewController.swift
//  PhotoView
//
//  Created by Macintosh on 4/20/16.
//  Copyright © 2016 Appinspire. All rights reserved.
//

import UIKit

class PopUpViewController: UIViewController {
    
    @IBOutlet weak var fullImageView: UIImageView!
    var photoCollection = [PhotoInfo]()
    override func viewDidLoad() {
        super.viewDidLoad()
        print(" popup loaded \(photoCollection.count)")
        let img = self.photoCollection[0].image
        fullImageView.contentMode = .ScaleAspectFit
        //fullImageView.clipsToBounds = true
        fullImageView.image = img
        //let imgView = UIImageView(image: img)
        //imgView.contentMode = .ScaleAspectFill
        //
        //imgView.frame = CGRectMake(0, 0, 92, 92);
//        self.addSubview(imgView)
        
    }

}
