-- Mirror Coat / Counter (Normal Trap)
-- Activate only during your opponent's Battle Phase, after a monster your opponent controls battles:
-- Declare 1 card type (Monster, Spell, or Trap), then reveal the top card of your opponent's Deck. If it is
-- the declared type, inflict damage to your opponent equal to twice that monster's ATK. Then shuffle the
-- revealed card into the Deck. You can only activate 1 "Mirror Coat / Counter" per turn.
-- PATTERN: "after a monster battles" = EVENT_BATTLED (right after damage calculation, still in the Damage
-- Step, so it needs EFFECT_FLAG_DAMAGE_STEP). Declaring a card type = Duel.SelectOption(tp,70,71,72).
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_BATTLED)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP)
	e1:SetCountLimit(1,id,EFFECT_COUNT_CODE_OATH)   -- only 1 activation per turn
	e1:SetCondition(function(e,tp)
		local a=Duel.GetAttacker()
		return Duel.IsTurnPlayer(1-tp) and a and a:IsControler(1-tp)
	end)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
local TYPES={TYPE_MONSTER,TYPE_SPELL,TYPE_TRAP}
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetFieldGroupCount(tp,0,LOCATION_DECK)>0 end
	local a=Duel.GetAttacker()
	e:SetLabel(math.max(a:GetAttack(),0)*2)        -- the damage, using the ATK it battled with
	Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,1-tp,e:GetLabel())
end
function s.activate(e,tp)
	-- 70/71/72 = "Monster card" / "Spell card" / "Trap card"
	local declared=TYPES[Duel.SelectOption(tp,70,71,72)+1]
	local tc=Duel.GetDecktopGroup(1-tp,1):GetFirst()
	if not tc then return end
	Duel.ConfirmDecktop(1-tp,1)                    -- both players see it
	if tc:IsType(declared) then
		Duel.Damage(1-tp,e:GetLabel(),REASON_EFFECT)
	end
	Duel.ShuffleDeck(1-tp)
end
