(async () => {
	const states = [12,27,16,13,29,23,53,32,52,21,51,50,31,15,25,41,26,22,33,24,43,11,14,42,35,28,17]
	states.forEach((state) => {
		let month=1
		let initialDate = ""
		let finalDate = ""
		let day = 31
		for (year = 2000; year <= 2018; year++) {
			for (month = 1; month <= 12; month++) {
				switch (month) {
					case 1:
					case 3:
					case 5:
					case 7:
					case 8:
					case 10:
					case 12:
						day=31
						break
					case 2:
						switch (year) {
							case 2000:						
							case 2004:
							case 2008:
							case 2012:
							case 2016:
								day=29
								break
							default:
								day=28
						}
						break
					default:
						day=30
				}
				day = day < 10 ? "0" + day : day
				month = month < 10 ? "0" + month : month
				initialDate = `01/${month}/${year}`
				finalDate = `${day}/${month}/${year}`
				file=`${state}_${month}_${year}.csv`
				console.log(`${file}`)
				//request_and_save_to(file)
			}
		}
	})
})()
