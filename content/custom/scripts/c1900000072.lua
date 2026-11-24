-- Venomoth
-- Evolution Summon from "Venonat" (hard once per turn).
-- Once per turn (Quick Effect): You can activate 1 of these effects:
-- * Look at 1 random card in your opponent's hand.
-- * Look at 1 Set card your opponent controls.
-- You can only use this effect of "Venomoth" once per turn.
-- PATTERN: "activate 1 of these effects" = in the target, offer only the choices that can be used now
-- (Duel.SelectOption with the Prompts), remember the choice in e:SetLabel.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000071)   -- from Venonat

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetType(EFFECT_TYPE_QUICK_O)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCountLimit(1,id)                   -- hard once per turn
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
s.listed_names={1900000071}

function s.canHand(tp) return Duel.GetFieldGroupCount(tp,0,LOCATION_HAND)>0 end
function s.canSet(tp) return Duel.IsExistingMatchingCard(Card.IsFacedown,tp,0,LOCATION_ONFIELD,1,nil) end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local h,st=s.canHand(tp),s.canSet(tp)
	if chk==0 then return h or st end
	-- Prompt 2 = random card in hand, Prompt 3 = Set card. Only list the ones possible right now.
	local opts,labels={},{}
	if h then table.insert(opts,aux.Stringid(id,1)) table.insert(labels,1) end
	if st then table.insert(opts,aux.Stringid(id,2)) table.insert(labels,2) end
	local pick=Duel.SelectOption(tp,table.unpack(opts))+1
	e:SetLabel(labels[pick])
end
function s.operation(e,tp)
	if e:GetLabel()==1 then
		local g=Duel.GetFieldGroup(tp,0,LOCATION_HAND)
		if #g==0 then return end
		local rg=g:RandomSelect(tp,1)
		Duel.ConfirmCards(tp,rg)
		Duel.ShuffleHand(1-tp)
	else
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEDOWN)
		local g=Duel.SelectMatchingCard(tp,Card.IsFacedown,tp,0,LOCATION_ONFIELD,1,1,nil)
		if #g>0 then Duel.ConfirmCards(tp,g) end
	end
end
