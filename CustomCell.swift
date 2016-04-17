//
//  photoCollectionView.swift
//  PhotoView
//
//  Created by Macintosh on 4/17/16.
//  Copyright © 2016 Appinspire. All rights reserved.
//
import UIKit
import Photos

class CustomCell: UICollectionViewCell {
    var imageView:UIImageView
    var image:UIImage
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
