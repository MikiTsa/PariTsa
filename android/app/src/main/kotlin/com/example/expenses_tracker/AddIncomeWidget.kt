package com.example.expenses_tracker

class AddIncomeWidget : AddTransactionWidget() {
    override val layoutId    = R.layout.add_income_widget
    override val action      = ACTION_ADD_INCOME
    override val requestCode = 1002
}
