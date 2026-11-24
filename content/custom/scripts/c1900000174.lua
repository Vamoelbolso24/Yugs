-- Elite Four (Normal Spell)
-- Activate 1 of these effects:
-- 1. Reveal 2 "Gym Leader" Continuous Spells with different names from your Deck; your opponent randomly adds 1 of
--    them to your hand, also shuffle the other into the Deck.
-- 2. Reveal from your Deck 1 "Gym Leader" Continuous Spell, 1 Spell/Trap with a different name that states
--    "Pokemon" in its text, and 1 Level 7 or higher Pokemon monster; your opponent randomly adds 1 of them to your
--    hand, also shuffle the rest into the Deck.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_series={SET_GYM_LEADER}
function s.gym(c) return c:IsSetCard(SET_GYM_LEADER) and c:IsType(TYPE_CONTINUOUS) and c:IsSpell() and c:IsAbleToHand() end
function s.st(c) return Pokemon.MentionsPokemon(c) and not c:IsSetCard(SET_GYM_LEADER) and c:IsAbleToHand() end
function s.big(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsLevelAbove(7) and c:IsAbleToHand() end
-- option 1: 2 different Gym Leaders
function s.can1(tp) return Duel.GetMatchingGroup(s.gym,tp,LOCATION_DECK,0,nil):GetClassCount(Card.GetCode)>=2 end
-- option 2: 1 of each kind (the Spell/Trap isn't a Gym Leader, so its name is different)
function s.can2(tp)
	return Duel.IsExistingMatchingCard(s.gym,tp,LOCATION_DECK,0,1,nil) and Duel.IsExistingMatchingCard(s.st,tp,LOCATION_DECK,0,1,nil)
		and Duel.IsExistingMatchingCard(s.big,tp,LOCATION_DECK,0,1,nil)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local a,b=s.can1(tp),s.can2(tp)
	if chk==0 then return a or b end
	local op
	if a and b then op=Duel.SelectOption(tp,aux.Stringid(id,0),aux.Stringid(id,1))
	elseif a then op=Duel.SelectOption(tp,aux.Stringid(id,0))
	else op=Duel.SelectOption(tp,aux.Stringid(id,1))+1 end
	e:SetLabel(op)
	Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
end
function s.activate(e,tp)
	local g=Group.CreateGroup()
	if e:GetLabel()==0 then
		if not s.can1(tp) then return end
		local all=Duel.GetMatchingGroup(s.gym,tp,LOCATION_DECK,0,nil)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_CONFIRM)
		g=aux.SelectUnselectGroup(all,e,tp,2,2,aux.dncheck,1,tp,HINTMSG_CONFIRM)   -- dncheck = different names
	else
		if not s.can2(tp) then return end
		for _,f in ipairs({s.gym,s.st,s.big}) do
			Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_CONFIRM)
			g:Merge(Duel.SelectMatchingCard(tp,f,tp,LOCATION_DECK,0,1,1,nil))
		end
	end
	if #g>0 then Pokemon.RevealRandomAdd(tp,g) end
end
