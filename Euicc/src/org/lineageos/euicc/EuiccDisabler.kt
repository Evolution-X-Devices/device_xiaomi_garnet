/*
 * Copyright (C) 2021 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.euicc

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.PackageManager.PackageInfoFlags
import android.util.Log
import android.os.SystemProperties

object EuiccDisabler {
    private const val TAG = "XiaomiEuiccDisabler"

    private val EUICC_DEPENDENCIES = listOf(
        "com.google.android.gms",
        "com.google.android.gsf",
    )

    private val EUICC_PACKAGES = listOf(
        "com.google.android.euicc",
    )

    private fun isInstalledAndEnabled(pm: PackageManager, pkgName: String) = runCatching {
        val info = pm.getPackageInfo(pkgName, PackageInfoFlags.of(0))
        Log.d(TAG, "package $pkgName installed, enabled = ${info.applicationInfo.enabled}")
        info.applicationInfo.enabled
    }.getOrDefault(false)

    fun enableOrDisableEuicc(context: Context) {
        val pm = context.packageManager
        val sku = SystemProperties.get("ro.boot.product.hardware.sku")
        val disable = if (sku == "IN" || sku == "CN") {
            Log.d(TAG, "Disabling apps due to IN or CN SKU")
            true // Disable if SKU is IN or CN
        } else {
            EUICC_DEPENDENCIES.any { !isInstalledAndEnabled(pm, it) }
        }
        val flag = if (disable) {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        }

        for (pkg in EUICC_PACKAGES) {
            pm.setApplicationEnabledSetting(pkg, flag, 0)
        }
    }
}
