package com.example.fit_kit

import io.flutter.plugin.common.MethodCall
import java.util.*

abstract class ReadRequest<T : Type> private constructor(
        val type: T,
        val dateFrom: Date,
        val dateTo: Date,
        val limit: Int?,
        val interval: Int
) {

    class Sample(type: Type.Sample, dateFrom: Date, dateTo: Date, limit: Int?, interval: Int)
        : ReadRequest<Type.Sample>(type, dateFrom, dateTo, limit, interval)

    class Activity(type: Type.Activity, dateFrom: Date, dateTo: Date, limit: Int?, interval: Int)
        : ReadRequest<Type.Activity>(type, dateFrom, dateTo, limit, interval)

    companion object {
        @Throws
        fun fromCall(call: MethodCall): ReadRequest<*> {
            val type = call.argument<String>("type")?.fromDartType()
                    ?: throw Exception("type is not defined")
            val dateFrom = safeLong(call, "date_from")?.let { Date(it) }
                    ?: throw Exception("date_from is not defined")
            val dateTo = safeLong(call, "date_to")?.let { Date(it) }
                    ?: throw Exception("date_to is not defined")
            val limit = call.argument<Int?>("limit")
            val interval = call.argument<Int?>("interval")
                    ?: throw Exception("interval is not defined")

            return when (type) {
                is Type.Sample -> Sample(type, dateFrom, dateTo, limit, interval)
                is Type.Activity -> Activity(type, dateFrom, dateTo, limit, interval)
            }
        }

        /**
         *  Dart | Android
         *  int	   java.lang.Integer
         *  int    java.lang.Long
         */
        private fun safeLong(call: MethodCall, key: String): Long? {
            val value: Any? = call.argument(key)
            return when (value) {
                is Int -> value.toLong()
                is Long -> value
                else -> null
            }
        }
    }
}