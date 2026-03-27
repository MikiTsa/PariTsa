package com.example.expenses_tracker

class AddSavingWidget : AddTransactionWidget() {
    override val layoutId    = R.layout.add_saving_widget
    override val action      = ACTION_ADD_SAVING
    override val requestCode = 1003
}
