class_name ChatFilter
extends RefCounted
## Basic chat/name filter (English + Arabic). Bad words are replaced with
## asterisks; links, phone numbers and e-mails are hidden to protect kids.
## Runs on the server/host (authoritative) and again on every client.

const WORDS: Array[String] = [
	"fuck", "shit", "bitch", "asshole", "bastard", "dick", "pussy", "cunt", "slut", "whore",
	"nigger", "nigga", "faggot", "retard", "porn", "sex", "nude", "kill yourself", "kys",
	"كس", "زب", "شرموط", "شرموطة", "منيك", "منيوك", "قحبة", "قحبه", "عرص", "خول",
	"متناك", "نيك", "زبي", "طيز", "كلب", "حمار", "يلعن",
]


static func clean(text: String) -> String:
	var out := text
	var lower := out.to_lower()
	for w in WORDS:
		var idx := lower.find(w)
		while idx >= 0:
			var stars := "*".repeat(w.length())
			out = out.substr(0, idx) + stars + out.substr(idx + w.length())
			lower = lower.substr(0, idx) + stars + lower.substr(idx + w.length())
			idx = lower.find(w, idx + w.length())
	out = _hide_contacts(out)
	return out


static func is_clean(text: String) -> bool:
	return clean(text) == text


## Hides URLs, e-mails and long digit sequences (phone numbers).
static func _hide_contacts(text: String) -> String:
	var re_url := RegEx.new()
	re_url.compile("(?i)(https?://\\S+|www\\.\\S+|\\S+\\.(com|net|org|io|gg|me)\\b)")
	var t := re_url.sub(text, "[link]", true)
	var re_mail := RegEx.new()
	re_mail.compile("\\S+@\\S+")
	t = re_mail.sub(t, "[hidden]", true)
	var re_phone := RegEx.new()
	re_phone.compile("(\\+?\\d[\\d\\s\\-]{6,}\\d)")
	t = re_phone.sub(t, "[hidden]", true)
	return t
