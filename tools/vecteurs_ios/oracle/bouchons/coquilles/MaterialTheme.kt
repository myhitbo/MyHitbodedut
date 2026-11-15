package com.google.android.material.theme

import android.content.Context
import android.util.AttributeSet
import androidx.appcompat.widget.AppCompatImageView

open class MaterialComponentsViewInflater {
    protected open fun createImageView(context: Context, attrs: AttributeSet?): AppCompatImageView = AppCompatImageView(context, attrs)
}
