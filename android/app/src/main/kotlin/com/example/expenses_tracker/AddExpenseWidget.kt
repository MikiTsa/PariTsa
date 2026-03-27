package com.example.expenses_tracker

class AddExpenseWidget : AddTransactionWidget() {
    override val layoutId    = R.layout.add_expense_widget
    override val action      = ACTION_ADD_EXPENSE
    override val requestCode = 1001
}
