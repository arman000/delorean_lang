require 'parser'
p = DeloreanParser.new
t = p.parse("= 1+1")

l = []
t.convert(l)

t = p.parse("= a=b")

######################################################################

load 'lib/parser/g2.rb'
load 'lib/parser/g2nodes.rb'

require 'parser'
p = G2Parser.new

t = p.parse("a = 22+33")
t.check([])

t = p.parse("a = 22")
t = p.parse("a = b")
t = p.parse("a = b.c")
t.check([])

t = p.parse("a = (22+1)")
t = p.parse("a = f()")
t = p.parse("a = f(1,2) ? x : y")
t = p.parse("a = !f() || b")
t = p.parse("a = 'a' + 'b'")
t = p.parse('a = "a" + "bbb"')

t = p.parse('a = Rate.fn(name: name, note_rate: note_rate)')

t = p.parse('a = a.b.c')
t = p.parse('a = Rate.fn(name: x.y.z, note_rate: "hello")')
t = p.parse("a = -a + b")

t = p.parse("a = f(1, y, z)")
t.check([])

t = p.parse("int a = 22")

######################################################################

require 'delorean'
p = DeloreanParser.new

t = p.parse("a=1")
t = p.parse("A:")
t = p.parse("A: B")

######################################################################

source = <<eos
A:
 integer x = 123
 y = 456
B: A
 x = 333
eos

require 'delorean'
e=Delorean::Engine.new
c=e.parse(source)

######################################################################

require 'delorean'
sm=Delorean::SigMap.new
sm.add_map(Delorean::OPFUNCS)

fdef = Delorean::FuncDef.new([Delorean::TNumber], Delorean::TBoolean)

sm.get_type('>', [Delorean::TDecimal, Delorean::TInteger])

sm.get_type('>', [Delorean::TString, Delorean::TInteger])

sm.get_type('+', [Delorean::TString, Delorean::TInteger])

sm.get_type('+', [Delorean::TString, Delorean::TString])

sm.get_type('+', [Delorean::TInteger, Delorean::TInteger])

sm.get_type('-', [Delorean::TDecimal])

sm.add_map({"max" => Delorean::FuncDef.new(Delorean::TInteger..Delorean::TInteger, Delorean::TInteger)})
sm.add_map({"min" => Delorean::FuncDef.new(Delorean::TNumber..Delorean::TNumber, Delorean::TDecimal)})

sm.get_type('min', [Delorean::TInteger, Delorean::TInteger, Delorean::TInteger])

require 'delorean'
Delorean::BaseModule.MAX_sig

######################################################################
source = <<eos
A:
 integer x = MAX(1, 2, 3)
 # integer a = MAX()
 #decimal y = x
 # integer z = y * y

B: A
 y = "aa"
# string x = "a"
eos

source = <<eos
A:
 Rate r = Rate.first()
 decimal x = r.coupon
 decimal y = Rate.get_coupon("a", 1.0)
eos

require 'delorean'
e=Delorean::Engine.new
c=e.parse(source)

######################################################################

s = [Delorean::FuncDef, Delorean::TBase, Delorean::TNumber]
t = [Delorean::TNumber, Delorean::TNumber, Delorean::TNumber]
s.each_with_index.reject { |ss, i| ss <= t[i] }

c.sigmap.get_type2('-', [Delorean::TBase])

######################################################################

source = <<eos
A:
 integer x = MAX(1, 2, 3)
 integer y = x * 3 + 4
eos

require 'delorean'
e=Delorean::Engine.new
c=e.parse(source)

######################################################################

source = <<eos
A:
 boolean b = 1.0 > 2
 decimal d = (1-1) + (2+2.0)
B: A
 boolean b = false
 integer x = MAX(1, 2, 3) + 123
 integer y = x * 3 + 4
C:
 Rate r = Rate.first()
 decimal x = r.coupon
 decimal y = Rate.get_coupon("a", 1.0) + 1.23
 boolean b = (x>=y) && (y>=x)
eos

require 'delorean'
e=Delorean::Engine.new
c=e.parse(source)

