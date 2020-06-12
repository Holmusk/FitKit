import Flutter
import UIKit
import HealthKit

public class SwiftFitKitPlugin: NSObject, FlutterPlugin {

    private let TAG = "FitKit";

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "fit_kit", binaryMessenger: registrar.messenger())
        let instance = SwiftFitKitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var healthStore: HKHealthStore? = nil;

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(FlutterError(code: TAG, message: "Not supported", details: nil))
            return
        }

        if (healthStore == nil) {
            healthStore = HKHealthStore();
        }

        do {
            if (call.method == "hasPermissions") {
                let request = try PermissionsRequest.fromCall(call: call)
                hasPermissions(request: request, result: result)
            } else if (call.method == "requestPermissions") {
                let request = try PermissionsRequest.fromCall(call: call)
                requestPermissions(request: request, result: result)
            } else if (call.method == "revokePermissions") {
                revokePermissions(result: result)
            } else if (call.method == "read") {
                let request = try ReadRequest.fromCall(call: call)
                read(request: request, result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        } catch {
            result(FlutterError(code: TAG, message: "Error \(error)", details: nil))
        }
    }


    /**
    * On iOS you can only know if user has responded to request access screen.
    * Not possible to tell if he has allowed access to read.
    *
    *   # getRequestStatusForAuthorization #
    *   If "status == unnecessary" means if requestAuthorization will be called request access screen will not be shown.
    *   So user has already responded to request access screen and kinda has permissions.
    *
    *   # authorizationStatus #
    *   If "status == notDetermined" user has not responded to request access screen.
    *   Once he responds no matter of the result status will be sharingDenied.
    */
    private func hasPermissions(request: PermissionsRequest, result: @escaping FlutterResult) {
        if #available(iOS 12.0, *) {
            healthStore!.getRequestStatusForAuthorization(toShare: [], read: Set(request.sampleTypes)) { (status, error) in
                guard error == nil else {
                    result(FlutterError(code: self.TAG, message: "hasPermissions", details: error))
                    return
                }

                guard status == HKAuthorizationRequestStatus.unnecessary else {
                    result(false)
                    return
                }

                result(true)
            }
        } else {
            let authorized = request.sampleTypes.map {
                        healthStore!.authorizationStatus(for: $0)
                    }
                    .allSatisfy {
                        $0 != HKAuthorizationStatus.notDetermined
                    }
            result(authorized)
        }
    }

    private func requestPermissions(request: PermissionsRequest, result: @escaping FlutterResult) {
        requestAuthorization(sampleTypes: request.sampleTypes) { success, error in
            guard success else {
                result(false)
                return
            }

            result(true)
        }
    }

    /**
    * Not supported by HealthKit.
    */
    private func revokePermissions(result: @escaping FlutterResult) {
        result(nil)
    }

    private func read(request: ReadRequest, result: @escaping FlutterResult) {
        requestAuthorization(sampleTypes: [request.sampleType]) { success, error in
            guard success else {
                result(error)
                return
            }

            self.readSample(request: request, result: result)
        }
    }

    private func requestAuthorization(sampleTypes: Array<HKSampleType>, completion: @escaping (Bool, FlutterError?) -> Void) {
        healthStore!.requestAuthorization(toShare: nil, read: Set(sampleTypes)) { (success, error) in
            guard success else {
                completion(false, FlutterError(code: self.TAG, message: "Error \(error?.localizedDescription ?? "empty")", details: nil))
                return
            }

            completion(true, nil)
        }
    }

    private func readSample(request: ReadRequest, result: @escaping FlutterResult) {
        print("readSample: \(request.type)")
        
        let stepQuantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!

        if(request.sampleType == stepQuantityType){
            let dayDifference = Calendar.current.dateComponents([.day], from: request.dateFrom, to: request.dateTo)
            let lastXnumOfDays = Calendar.current.date(byAdding: .day, value: -dayDifference.day!, to: Date())!
            var interval = DateComponents()
            interval.minute = request.interval
            let query = HKStatisticsCollectionQuery(quantityType: stepQuantityType,
                                            quantitySamplePredicate: nil,
                                            options: .cumulativeSum,
                                            anchorDate: lastXnumOfDays,
                                            intervalComponents: interval)
            var samples:[[String:Any]] = []
            query.initialResultsHandler = {
                query, results, error in
                guard let statsCollection = results else {
                    result(FlutterError(code: self.TAG, message: "An error occurred while calculating the statistic", details: error))
                    return
                }
                let endDate = Date()
                statsCollection.enumerateStatistics(from: lastXnumOfDays, to: endDate, with: { (statistics, stop) in
                    if let quantity = statistics.sumQuantity() {
                        let startDateTime = statistics.startDate
                        let endDateTime = statistics.startDate.addingTimeInterval(TimeInterval(60 * request.interval))
                        let value = quantity.doubleValue(for: HKUnit.count())
                        samples.append([
                            "value": value,
                            "date_from": startDateTime,
                            "date_to": endDateTime
                        ])

                        }
                    })
                result(samples.map{
                    sample -> NSDictionary in
                        [
                            "value": sample["value"]!,
                            "date_from": Int((sample["date_from"]! as AnyObject).timeIntervalSince1970 * 1000),
                            "date_to": Int((sample["date_to"]! as AnyObject).timeIntervalSince1970 * 1000),
                            "source": "Health",
                            "user_entered": false
                        ]
                })
            }
            healthStore!.execute(query)
        } else {
            let predicate = HKQuery.predicateForSamples(withStart: request.dateFrom, end: request.dateTo, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: request.limit == nil)

            let query = HKSampleQuery(sampleType: request.sampleType, predicate: predicate, limit: request.limit ?? HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) {
                _, samplesOrNil, error in

                guard var samples = samplesOrNil else {
                    result(FlutterError(code: self.TAG, message: "Results are null", details: error))
                    return
                }

                if (request.limit != nil) {
                    // if limit is used sort back to ascending
                    samples = samples.sorted(by: { $0.startDate.compare($1.startDate) == .orderedAscending })
                }

                print(samples)
                result(samples.map { sample -> NSDictionary in
                    [
                        "value": self.readValue(sample: sample, unit: request.unit),
                        "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                        "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                        "source": self.readSource(sample: sample),
                        "user_entered": sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true
                    ]
                })
            }
            healthStore!.execute(query)
        }

        
        
    }

    private func readValue(sample: HKSample, unit: HKUnit) -> Any {
        if let sample = sample as? HKQuantitySample {
            return sample.quantity.doubleValue(for: unit)
        } else if let sample = sample as? HKCategorySample {
            return sample.value
        }

        return -1
    }

    private func readSource(sample: HKSample) -> String {
        if #available(iOS 9, *) {
            return sample.sourceRevision.source.name;
        }

        return sample.source.name;
    }
    
}
