# This file is used to render conversation data search API response.

json.id conversation.display_id
json.uuid conversation.uuid
json.created_at conversation.created_at.to_i
json.contact do
  json.id conversation.contact.id
  json.name conversation.contact.name
end
json.inbox do
  json.id conversation.inbox.id
  json.name conversation.inbox.name
  json.channel_type conversation.inbox.channel_type
end
json.messages do
  json.array! conversation.messages do |message|
    json.content message.content
    json.id message.id
    json.sender_name message.sender.name if message.sender
    json.message_type message.message_type_before_type_cast
    json.created_at message.created_at.to_i
  end
end
json.account_id conversation.account_id
json.deal_stage conversation.deal_stage
json.deal_value conversation.deal_value
json.deal_currency conversation.deal_currency
json.deal_value_clp conversation.deal_value_clp
json.lost_reason conversation.lost_reason
json.fx_rate_usd_clp conversation.fx_rate_usd_clp
json.next_follow_up_at conversation.next_follow_up_at&.to_i
json.last_contacted_at conversation.last_contacted_at&.to_i
