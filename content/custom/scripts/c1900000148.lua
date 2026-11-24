-- Cloyster
-- Evolution Summon from "Shellder" (hard once per turn).
-- During your Draw Phase, if you draw a WATER Pokemon monster for your normal draw: You can reveal it; draw 1 card.
-- You can only use each of these effects of "Cloyster" once per turn:
-- * If this card would be destroyed by battle, you can send the top card of your Deck to the GY instead, and if
--   that card was a WATER Pokemon monster, inflict 500 damage to your opponent.
-- * When your opponent activates a Spell/Trap card or effect that targets this card (Quick Effect): You can send
--   the top card of your Deck to the GY; negate the activation, and if you do, destroy that card.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000147)   -- from Shellder
	-- Draw Phase: reveal a WATER Pokemon, draw 1
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DRAW)
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_DRAW)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCondition(function(e,tp,eg,ep,ev,re,r)
		return ep==tp and r==REASON_RULE and Duel.GetCurrentPhase()==PHASE_DRAW and eg:IsExists(Pokemon.IsWaterPokemon,1,nil)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsPlayerCanDraw(tp,1) end
		Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,1)
	end)
	e1:SetOperation(function(e,tp,eg)
		local g=eg:Filter(Pokemon.IsWaterPokemon,nil)
		if #g==0 then return end
		Duel.ConfirmCards(1-tp,g)                  -- reveal it
		Duel.ShuffleHand(tp)
		Duel.Draw(tp,1,REASON_EFFECT)
	end)
	c:RegisterEffect(e1)
	-- Battle destruction replacement (once per turn)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCode(EFFECT_DESTROY_REPLACE)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return c:IsReason(REASON_BATTLE) and not c:IsReason(REASON_REPLACE)
			and Duel.GetFlagEffect(tp,id)==0 and Duel.IsPlayerCanDiscardDeck(tp,1) end
		if not Duel.SelectEffectYesNo(tp,c,aux.Stringid(id,1)) then return false end
		Duel.RegisterFlagEffect(tp,id,RESET_PHASE|PHASE_END,0,1)   -- hard once per turn
		return true
	end)
	e2:SetOperation(function(e,tp)
		local tc=Pokemon.MillTop(tp)
		if Pokemon.IsWaterPokemon(tc) then Duel.Damage(1-tp,500,REASON_EFFECT) end
	end)
	c:RegisterEffect(e2)
	-- Negate a Spell/Trap targeting it
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,2))
	e3:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e3:SetType(EFFECT_TYPE_QUICK_O)
	e3:SetCode(EVENT_CHAINING)
	e3:SetRange(LOCATION_MZONE)
	e3:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e3:SetCountLimit(1,{id,1})
	e3:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		if rp~=1-tp or not re:IsActiveType(TYPE_SPELL|TYPE_TRAP) or not Duel.IsChainNegatable(ev) then return false end
		if not re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) then return false end
		local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
		return g and g:IsContains(e:GetHandler())
	end)
	e3:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsPlayerCanDiscardDeckAsCost(tp,1) end
		Duel.DiscardDeck(tp,1,REASON_COST)
	end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
		if re:GetHandler():IsDestructable() and re:GetHandler():IsRelateToEffect(re) then
			Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0)
		end
	end)
	e3:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then Duel.Destroy(eg,REASON_EFFECT) end
	end)
	c:RegisterEffect(e3)
end
s.listed_names={1900000147}
