# AHLocationManager
Swift 定位权限封装，坐标转换

#### 功能列表
+ 获取系统经纬度坐标
+ GPS国际标准，高德坐标，百度坐标相互转换
+ 定位权限被拒弹框提示
#### 使用方法
##### 1，将源文件AHLocationManager.swift引入项目中
##### 2，添加info.plist 描述
```
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>App需要您的同意,才能访问位置以便xxx</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>App需要您的同意,才能访问位置以便xxx</string>
```
##### 3，调用
```
        AHLocationManager.shared.startPositioning(self)
        AHLocationManager.shared.locationType = .BD
        AHLocationManager.shared.postionUpdateClosure = {[weak self] (locModel) in
            if locModel.locationError != nil {
                self?.locationLabel.text = "定位失败"
            }else{
                if let coordinate = locModel.coordinate{
                    self?.latLabel.text = "\(coordinate.latitude)"
                    self?.longLabel.text = "\(coordinate.longitude)"
                }
                
                if let place = locModel.clplacemark {
                    self?.locationLabel.text = "\(place.administrativeArea ?? "")\(place.locality ?? "")\(place.subLocality ?? "")\(place.thoroughfare ?? "")\(place.name ?? "")"
                }
                
            }
        }
```
```
enum AHLocationType{
    /// WGS-84：是国际标准，GPS坐标（Google Earth使用、或者GPS模块）
    case WGS
    /// GCJ-02：中国坐标偏移标准，Google Map、高德、腾讯使用
    case GCJ
    /// BD-09 ：百度坐标偏移标准，Baidu Map使用
    case BD
    
}
```
通过`locationType `可指定返回经纬度类型，默认返回的经纬度为`WGS-84`
> 坐标转换参考[https://www.jianshu.com/p/abdb35b0ba78](https://www.jianshu.com/p/abdb35b0ba78)
> 坐标转换可能存在一定误差，使用时自行斟酌
