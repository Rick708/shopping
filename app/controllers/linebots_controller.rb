class LinebotsController < ApplicationController
  require 'line/bot'

  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          input = event.message['text']
          messages = search_and_create_messages(input)
          client.reply_message(event['replyToken'], messages)
        end
      end
    end
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end

  def search_and_create_messages(keyword)
    request = Vacuum.new(marketplace: 'JP',
                         access_key: ENV['AMAZON_API_ACCESS_KEY'],
                         secret_key: ENV['AMAZON_API_SECRET_KEY'],
                         partner_tag: ENV['ASSOCIATE_TAG'])

    res1 = request.search_items(keywords: keyword,
                                resources: ['BrowseNodeInfo.BrowseNodes']).to_h
    browse_node_no = res1.dig('SearchResult', 'Items').first.dig('BrowseNodeInfo', 'BrowseNodes').first.dig('Id')
    res2 = request.search_items(keywords: keyword,
                                browse_node_id: browse_node_no,
                                resources: ['ItemInfo.Title', 'Images.Primary.Large', 'Offers.Listings.Price']).to_h
    items = res2.dig('SearchResult', 'Items')

    make_reply_content(items)
  end
  def make_reply_content(items)
    {
      "type": "flex",
      "altText": "This is a Flex Message",
      "contents":
      {
        "type": "carousel",
        "contents": [
          make_part(items[0], 1),
          make_part(items[1], 2),
          make_part(items[2], 3)
        ]
      }
    }
  end


  def make_part(item, rank)
    title = item.get('ItemAttributes/Title')
    price = item.get('ItemAttributes/ListPrice/FormattedPrice') || item.get('OfferSummary/LowestNewPrice/FormattedPrice')
    url = bitly_shorten(item.get('DetailPageURL'))
    image = item.get('LargeImage/URL')
    {
      "type": "bubble",
      "hero": {
        "type": "image",
        "size": "full",
        "aspectRatio": "20:13",
        "aspectMode": "cover",
        "url": image
      },
      "body":
      {
        "type": "box",
        "layout": "vertical",
        "spacing": "sm",
        "contents": [
          {
            "type": "text",
            "text": "#{rank}位",
            "wrap": true,
            "margin": "md",
            "color": "#ff5551",
            "flex": 0
          },
          {
            "type": "text",
            "text": title,
            "wrap": true,
            "weight": "bold",
            "size": "lg"
          },
          {
            "type": "box",
            "layout": "baseline",
            "contents": [
              {
                "type": "text",
                "text": price,
                "wrap": true,
                "weight": "bold",
                "flex": 0
              }
            ]
          }
        ]
      },
      "footer": {
        "type": "box",
        "layout": "vertical",
        "spacing": "sm",
        "contents": [
          {
            "type": "button",
            "style": "primary",
            "action": {
              "type": "uri",
              "label": "Amazon商品ページへ",
              "uri": url
            }
          }
        ]
      }
    }
  end
end
