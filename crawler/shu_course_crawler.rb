require 'crawler_rocks'
require 'json'
require 'pry'
require 'iconv'

class ShihHsinUniversityCrawler

	def initialize year: nil, term: nil, update_progress: nil, after_each: nil

		@year = year-1911
		@term = term
		@update_progress_proc = update_progress
		@after_each_proc = after_each

		@query_url = 'https://ap2.shu.edu.tw/STU1/Loginguest.aspx'
		@result_url = 'https://ap2.shu.edu.tw/STU1/STU1/SC0102.aspx'
		@ic = Iconv.new('utf-8//translit//IGNORE', 'utf-8')
	end

	def courses
		@courses = []

		r = RestClient.get(@query_url)
		cookie = "ASP.NET_SessionId=#{r.cookies["ASP.NET_SessionId"]}"
		doc = Nokogiri::HTML(@ic.iconv(r))
		hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

		r = %x(curl -s '#{@query_url}' -H 'Cookie: #{cookie}' --data '__VIEWSTATE=#{URI.escape(hidden["__VIEWSTATE"], "=+/")}&LoginGuest_Guest.x=20&LoginGuest_Guest.y=20' --compressed)

		r = RestClient.get(@result_url, {"Cookie" => cookie })
		doc = Nokogiri::HTML(r)

		hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

		r = %x(curl -s '#{@result_url}' -H 'Cookie: #{cookie}' --data '__EVENTTARGET=SRH_setyear_SRH&__EVENTARGUMENT=&__VIEWSTATE=#{URI.escape(hidden["__VIEWSTATE"], "=+/")}&SRH_setyear_SRH=#{@year}' --compressed)
		doc = Nokogiri::HTML(r)

		hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

		r = %x(curl -s '#{@result_url}' -H 'Cookie: #{cookie}' --data '__EVENTTARGET=SRH_setterm_SRH&__EVENTARGUMENT=&__VIEWSTATE=#{URI.escape(hidden["__VIEWSTATE"], "=+/")}&SRH_setyear_SRH=#{@year}&SRH_setterm_SRH=#{@term}&SRH_teach_code_SRH=&SRH_teach_name=&SRH_majr_no=&SRH_grade=&SRH_class_no=&SRH_disp_cr_code=&SRH_full_name=&SRH_day_of_wk_SRH=' --compressed)
		doc = Nokogiri::HTML(r)

		hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

		r = %x(curl -s '#{@result_url}' -H 'Cookie: #{cookie}' --data '__EVENTTARGET=&__EVENTARGUMENT=&__VIEWSTATE=#{URI.escape(hidden["__VIEWSTATE"], "=+/")}&SRH_setyear_SRH=#{@year}&SRH_setterm_SRH=#{@term}&SRH_teach_code_SRH=&SRH_teach_name=&SRH_majr_no=&SRH_grade=&SRH_class_no=&SRH_disp_cr_code=&SRH_full_name=&SRH_day_of_wk_SRH=&SRH_search_button=%E6%90%9C%E5%B0%8B' --compressed)

		@result_url = "https://ap2.shu.edu.tw/STU1/STU1/SC0102.aspx?setyear_SRH=#{@year}&teach_code_SRH=&majr_no=&disp_cr_code=&day_of_wk_SRH=&setterm_SRH=#{@term}&teach_name=&grade=&full_name=&class_no=&"
		r = RestClient.get(@result_url, {"Cookie" => cookie })
		doc = Nokogiri::HTML(r)

		course_temp(doc)

		for page in 1..doc.css('span[id="GRD_ASPager_lblPageTotal"]').text.split(' ')[-1][0..-2].to_i - 1

			hidden = Hash[doc.css('input[type="hidden"]').map{|hidden| [hidden[:name], hidden[:value]]}]

			r = %x(curl -s '#{@result_url}' -H 'Cookie: #{cookie}' --data '__EVENTTARGET=GRD_ASPager%3AlnkNext&__EVENTARGUMENT=&__VIEWSTATE=#{URI.escape(hidden["__VIEWSTATE"], "=+/")}&SRH_setyear_SRH=#{@year}&SRH_setterm_SRH=#{@term}&SRH_teach_code_SRH=&SRH_teach_name=&SRH_majr_no=&SRH_grade=&SRH_class_no=&SRH_disp_cr_code=&SRH_full_name=&SRH_day_of_wk_SRH=&GRD_ASPager%3AtxtPage=#{page}' --compressed)
			doc = Nokogiri::HTML(r)

			course_temp(doc)
			# binding.pry if page == 10
		end
		@courses
	end

	def course_temp(doc)
		doc.css('table[id="GRD_DataGrid"] tr:nth-child(n+2)').map{|tr| tr}.each do |tr|
			data = tr.css('td').map{|td| td.text}

			course = {
				year: @year,
				term: @term,
				department: data[0],      # 開課系級
				general_code: data[1],    # 課程簡碼
				name: data[2],            # 學科名稱﹝課程大綱﹞學科英文名稱
				term_type: data[3],       # 年別
				credits: data[4],         # 學分數
				required: data[5],        # 選別 (必選修)
				lecturer: data[6],        # 授課教師
				day: data[7],             # 星期
				period: data[8],          # 節次
				location: data[9],        # 教室
				week_type: data[10],      # 週別
				notes: data[11],          # 備註說明
				}

			@after_each_proc.call(course: course) if @after_each_proc

			@courses << course
		end
	end
end

# crawler = ShihHsinUniversityCrawler.new(year: 2015, term: 1)
# File.write('courses.json', JSON.pretty_generate(crawler.courses()))
