//
//  PhotoInfo.swift
//  PhotoView
//
//  Created by Macintosh on 4/17/16.
//  Copyright © 2016 Appinspire. All rights reserved.
//

import Photos
class PhotoInfo{
    var image:UIImage
    var latitude:Double = 0.0
    var longitude:Double = 0.0
    var ID = ""
    
    init(img:UIImage, lat:Double, long:Double, id:String){
        image = img
        latitude = lat
        longitude = long
        ID = id
    }
}
