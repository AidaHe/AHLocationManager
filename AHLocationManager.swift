//
//  AHLocationManager.swift
//  LocationManager
//
//  Created by AidaHe on 2020/5/29.
//  Copyright © 2020 AidaHe. All rights reserved.
//

import UIKit
import CoreLocation

enum AHLocationType{
    /// WGS-84：是国际标准，GPS坐标（Google Earth使用、或者GPS模块）
    case WGS
    /// GCJ-02：中国坐标偏移标准，Google Map、高德、腾讯使用
    case GCJ
    /// BD-09 ：百度坐标偏移标准，Baidu Map使用
    case BD
    
}

enum AHLocationError:Error{
    case fetchPlacemarkError
}

struct AHLocationModel {
    var coordinate:CLLocationCoordinate2D?
    var clplacemark:CLPlacemark?
    var locationError:Error?
}

fileprivate let a = 6378245.0;
fileprivate let ee = 0.00669342162296594323;
fileprivate let pi = Double.pi;
fileprivate let xPi = pi  * 3000.0 / 180.0;
fileprivate let locRequestTitle = "定位服务未开启,是否前往开启?"
fileprivate let locHelpMessage = "请进入系统[设置]->[隐私]->[定位服务]中打开开关，并允许“xxx”使用定位服务"
/*
   坐标系：
     WGS-84：是国际标准，GPS坐标（Google Earth使用、或者GPS模块）
     GCJ-02：中国坐标偏移标准，Google Map、高德、腾讯使用
     BD-09 ：百度坐标偏移标准，Baidu Map使用
 */

typealias AHPostionUpdateClosure = (AHLocationModel) ->()

class AHLocationManager: NSObject {

    public static let shared = AHLocationManager()
    var postionUpdateClosure:AHPostionUpdateClosure?
    /// 坐标系标准默认WGS-84
    var locationType:AHLocationType = .WGS
    private var locationManager:CLLocationManager?
    private var viewController : UIViewController?
    
    func  startPositioning(_ vc:UIViewController) {
        viewController = vc
        if (self.locationManager != nil) && (CLLocationManager.authorizationStatus() == .denied) {
            // 定位提示
            locationDenied()
        } else {
            requestLocationServicesAuthorization()
        }
    }
    
    // 初始化定位
    private func requestLocationServicesAuthorization() {
        
        if (self.locationManager == nil) {
            self.locationManager = CLLocationManager()
            self.locationManager?.delegate = self
        }
        
        self.locationManager?.requestWhenInUseAuthorization()
        self.locationManager?.startUpdatingLocation()
        
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.notDetermined) {
            locationManager?.requestWhenInUseAuthorization()
        }
        
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse) {
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            let distance : CLLocationDistance = 10.0
            locationManager?.distanceFilter = distance
            locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager?.startUpdatingLocation()
        }
    }
    
    // 获取定位代理返回状态进行处理
    private func reportLocationServicesAuthorizationStatus(status:CLAuthorizationStatus) {
        
        if status == .notDetermined {
            // 未决定,继续请求授权
            requestLocationServicesAuthorization()
        } else if (status == .restricted) {
            // 受限制，尝试提示然后进入设置页面进行处理
            locationDenied()
        } else if (status == .denied) {
            // 受限制，尝试提示然后进入设置页面进行处理
            locationDenied()
        }
    }
    
    // MARK: -坐标转换
    // 将GPS坐标转换为高德坐标
    private func transformFromGPSToGD(wgsLoc:CLLocationCoordinate2D) ->CLLocationCoordinate2D {

        var adjustLoc:CLLocationCoordinate2D?
        if isLocationOutOfChina(location: wgsLoc){
            adjustLoc = wgsLoc
        }else{
            var adjustLat = transformLatWithX(x: wgsLoc.longitude - 105, y: wgsLoc.latitude - 35)
            var adjustLon = transformLonWithX(x: wgsLoc.longitude - 105, y: wgsLoc.latitude - 35)
            let radLat = wgsLoc.latitude / 180.0 * pi
            var magic = sin(radLat);
            magic = 1 - ee * magic * magic;
            let sqrtMagic = sqrt(magic);
            adjustLat = (adjustLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
            adjustLon = (adjustLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
            adjustLoc = CLLocationCoordinate2D(latitude: wgsLoc.latitude + adjustLat, longitude: wgsLoc.longitude + adjustLon)
        }
        return adjustLoc!
        
    }
    
    // 将高德坐标转换为百度坐标
    private func transformFromGCJToBaidu(_ cc:CLLocationCoordinate2D) ->CLLocationCoordinate2D{

        let z = sqrt(cc.longitude * cc.longitude + cc.latitude * cc.latitude) + 0.00002 * sqrt(cc.latitude * pi)
        let theta = atan2(cc.latitude, cc.longitude) + 0.000003 * cos(cc.longitude * pi)
        let baiduRes = CLLocationCoordinate2D(latitude: z*sin(theta) + 0.006, longitude: z*cos(theta) + 0.0065)
        return baiduRes
    }
    
    private func isLocationOutOfChina(location:CLLocationCoordinate2D) -> Bool{
        if (location.longitude < 72.004 || location.longitude > 137.8347 || location.latitude < 0.8293 || location.latitude > 55.8271){
            return true
        }
        return false;
    }
    
    private func transformLatWithX(x:Double,y:Double) -> Double{
        var lat = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(fabs(x));
        
        lat += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
        lat += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
        lat += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
        return lat
    }
    
    private func transformLonWithX(x:Double,y:Double) -> Double{
        var lon = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(fabs(x));
        lon += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
        lon += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
        lon += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
        return lon
    }
    
    // MARK: 定位权限未授权
    private func locationDenied(){
        viewController?.AHShowAlertView(title: locRequestTitle, message: locHelpMessage, cancelTitle: nil, confirmAction: {
            let url = URL(string: UIApplication.openSettingsURLString)
            if UIApplication.shared.canOpenURL(url!){
                if #available(iOS 10, *) {
                    UIApplication.shared.open(URL.init(string: UIApplication.openSettingsURLString)!, options: [:],
                                              completionHandler: {
                                                (success) in
                    })
                } else {
                    UIApplication.shared.openURL(URL.init(string: UIApplication.openSettingsURLString)!)
                }
            }
        }, cancelAction: {
            
        })
    }
    
}

extension AHLocationManager:CLLocationManagerDelegate{
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let location = locations.last ?? CLLocation()
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
             
            if error != nil {
                if let block = self.postionUpdateClosure{
                    var model = AHLocationModel()
                    model.locationError = error
                    block(model)
                }
                return
            }
            
            if let block = self.postionUpdateClosure{
                var model = AHLocationModel()
                switch self.locationType {
                case .WGS:
                    model.coordinate = location.coordinate
                case .GCJ:
                    let gcjCoordinate = self.transformFromGPSToGD(wgsLoc: location.coordinate)
                    model.coordinate = gcjCoordinate
                case .BD:
                    var baiduLocation = self.transformFromGPSToGD(wgsLoc:location.coordinate)
                    baiduLocation = self.transformFromGCJToBaidu(baiduLocation)
                    model.coordinate = baiduLocation
                }
                
                if let place = placemarks?[0]{
                    model.clplacemark = place
                }else{
                    model.locationError = AHLocationError.fetchPlacemarkError
                }
                
                block(model)
                
            }
            
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        reportLocationServicesAuthorizationStatus(status: status)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.locationManager?.stopUpdatingLocation()
    }
    
}


extension UIViewController{
    
    /// 显示系统弹框
    func AHShowAlertView(title:String,message:String?,cancelTitle:String?,confimTitle:String = "确定",confirmAction:@escaping () ->Void,cancelAction:@escaping () ->Void){
        let alertController = UIAlertController(title: title,
                        message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: confimTitle, style: .default) { (_) in
            confirmAction()
        }
        alertController.addAction(okAction)
        
        if let cancelText = cancelTitle {
            let cancelAction = UIAlertAction(title: cancelText, style: .default) { (_) in
                cancelAction()
            }
            alertController.addAction(cancelAction)
        }
        self.present(alertController, animated: true, completion: nil)
    }
    
}
