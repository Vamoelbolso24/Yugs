-- Fossil Pkmn - Aerodactyl
-- Cannot be Normal Summoned/Set. Must be Special Summoned (from your hand) by banishing 2 "Fossil Pkmn" monsters
-- from your GY. This card's Special Summon cannot be negated.
-- If this card destroys a monster by battle, banish it instead of sending it to the GY.
-- Once per turn: You can banish 1 "Fossil" card from your GY, then target 1 card on the field; banish it.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddFossilSummon(c,"banish",function(x) return x:IsMonster() and x:IsSetCard(SET_FOSSIL_PKMN) end,2,true)
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE)
	e0:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e0:SetCode(EFFECT_CANNOT_DISABLE_SPSUMMON)
	c:RegisterEffect(e0)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_BATTLE_DESTROY_REDIRECT)
	e1:SetValue(LOCATION_REMOVED)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_REMOVE)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCountLimit(1)
	e2:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.cfilter,tp,LOCATION_GRAVE,0,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
		local g=Duel.SelectMatchingCard(tp,s.cfilter,tp,LOCATION_GRAVE,0,1,1,nil)
		Duel.Remove(g,POS_FACEUP,REASON_COST)
	end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
		if chkc then return chkc:IsOnField() and chkc:IsAbleToRemove() end
		if chk==0 then return Duel.IsExistingTarget(Card.IsAbleToRemove,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,1,nil) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
		local g=Duel.SelectTarget(tp,Card.IsAbleToRemove,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,1,1,nil)
		Duel.SetOperationInfo(0,CATEGORY_REMOVE,g,1,0,0)
	end)
	e2:SetOperation(function(e)
		local tc=Duel.GetFirstTarget()
		if tc and tc:IsRelateToEffect(e) then Duel.Remove(tc,POS_FACEUP,REASON_EFFECT) end
	end)
	c:RegisterEffect(e2)
end
function s.cfilter(c) return c:IsSetCard(SET_FOSSIL) and c:IsAbleToRemoveAsCost() end
