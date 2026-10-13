package com.creditcall.chipdnamobiledemo.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.View.VISIBLE
import android.view.ViewGroup
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.creditcall.chipdnamobiledemo.R
import com.creditcall.chipdnamobiledemo.databinding.BottomsheetDialogFragmentItemListBinding
import com.creditcall.chipdnamobiledemo.databinding.LayoutItemBinding
import com.creditcall.chipdnamobiledemo.dto.Item
import com.google.android.material.bottomsheet.BottomSheetDialogFragment

class ItemListBottomSheetFragment private constructor(private val builder: Builder) :
  BottomSheetDialogFragment() {

  private lateinit var binding: BottomsheetDialogFragmentItemListBinding

  private lateinit var adapter: ItemAdapter

  override fun onCreateView(
    inflater: LayoutInflater,
    container: ViewGroup?,
    savedInstanceState: Bundle?
  ): View {
    binding = BottomsheetDialogFragmentItemListBinding.bind(
      inflater.inflate(R.layout.bottomsheet_dialog_fragment_item_list, container, false)
    )
    return binding.root
  }

  override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
    super.onViewCreated(view, savedInstanceState)
    with(binding) {
      titleTextView.text = builder.title
      builder.onRefresh?.let {
        refreshButton.visibility = VISIBLE
        refreshButton.setOnClickListener { it() }
      }
      itemRecyclerView.layoutManager =
        LinearLayoutManager(view.context, LinearLayoutManager.VERTICAL, false)
      val onClick: ((Any) -> Unit)? = if (builder.onClick != null) {
        {
          if (builder.dismissOnClick) {
            dismissAllowingStateLoss()
          }
          builder.onClick?.invoke(it)
        }
      } else null
      adapter = ItemAdapter(builder.data, onClick)
      itemRecyclerView.adapter = adapter
    }
  }

  fun updateItem(items: List<Item>) {
    adapter.update(items)
  }

  class Builder {
    var data: List<Item> = emptyList()
      private set
    var title: String? = null
      private set
    var onRefresh: (() -> Unit)? = null
      private set
    var onClick: ((Any) -> Unit)? = null
      private set
    var dismissOnClick: Boolean = true
      private set


    fun setData(data: List<Item>) = run {
      this.data = data
      this
    }

    fun setTitle(title: String) = run {
      this.title = title
      this
    }

    fun setOnRefresh(action: (() -> Unit)?) = run {
      this.onRefresh = action
      this
    }

    fun setOnClick(dismissOnClick: Boolean = true, action: (Any) -> Unit) = run {
      this.dismissOnClick = dismissOnClick
      this.onClick = action
      this
    }

    fun build() = ItemListBottomSheetFragment(this)
  }

  class ItemAdapter(private var items: List<Item>, private val onClick: ((Any) -> Unit)?) :
    RecyclerView.Adapter<ItemAdapter.ViewHolder>() {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
      ViewHolder(
        LayoutInflater.from(parent.context).inflate(R.layout.layout_item, parent, false)
      )

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
      with(holder.binding) {
        val item = items[position]
        root.setOnClickListener { onClick?.invoke(item.metadata) }
        titleTextView.text = item.description
      }
    }

    override fun getItemCount() = items.size

    fun update(items: List<Item>) {
      this.items = items
      notifyDataSetChanged()
    }

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
      val binding: LayoutItemBinding = LayoutItemBinding.bind(view)
    }

  }
}